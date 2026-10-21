// SMS/GG smoke capture (Verilator, headless, no SDL).
//
// Full smstang_top model (VERILATOR branch) with the ROM streamed through
// the rom_loading/rom_do path like verilator/sim_main.cpp. Scripted joypad
// input from a frame script; per-frame video hash + PPM dumps at selected
// frames; 16-bit stereo audio dump @48 kHz. No save image: the suite's SMS
// ROM is a homebrew without battery-backed RAM.
// Usage: smoke_sms <rom> <frames> <tag> [script] [dumps]
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <vector>
#include <utility>

#include "Vsmstang_top.h"
#include "Vsmstang_top_smstang_top.h"
#include "verilated.h"

#ifndef TANGCORE_SIM_THREADS
#define TANGCORE_SIM_THREADS 1
#endif

#define H_RES 256
#define V_RES 192

static Vsmstang_top *top;
static Vsmstang_top_smstang_top *sms;
static uint64_t sim_time = 0;

static inline void step() {
    top->clk_g = !top->clk_g;
    top->eval();
    sim_time++;
}

static void load_rom(const char *filename) {
    FILE *f = fopen(filename, "rb");
    if (!f) { printf("Cannot open file %s\n", filename); exit(1); }
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, size % 1024, SEEK_SET);
    size -= size % 1024;
    uint8_t *rom = (uint8_t *)malloc(size);
    if (fread(rom, 1, size, f) != (size_t)size) { printf("short read\n"); exit(1); }
    fclose(f);
    top->rom_loading = 1;
    step();
    for (long i = 0; i < size; i++) {
        top->rom_do = rom[i];
        top->rom_do_valid = 1;
        step();
        top->rom_do_valid = 0;
        for (int k = 0; k < 16; k++) step();
    }
    top->rom_loading = 0;
    step();
    free(rom);
}

static uint8_t scr[H_RES * V_RES * 3];

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::threadContextp()->threads(TANGCORE_SIM_THREADS);
    fprintf(stderr, "model threads: %u\n", Verilated::threadContextp()->threads());
    if (argc < 4) { fprintf(stderr, "usage: smoke_sms <rom> <frames> <tag> [script] [dumps]\n"); return 1; }
    const char *rompath = argv[1];
    long want_frames = atol(argv[2]);
    const char *tag = argv[3];
    std::vector<std::pair<long, uint16_t>> script;
    if (argc > 4) {
        FILE *sf = fopen(argv[4], "r");
        if (!sf) { fprintf(stderr, "cannot open script %s\n", argv[4]); return 1; }
        long fr; unsigned int btn;
        while (fscanf(sf, "%ld %x", &fr, &btn) == 2) script.push_back({fr, (uint16_t)btn});
        fclose(sf);
        printf("script: %zu entries\n", script.size());
    }
    bool dumpall[10000] = {false};
    if (argc > 5) {
        char *list = argv[5], *tok = strtok(list, ",");
        while (tok) { long f = atol(tok); if (f < 10000) dumpall[f] = true; tok = strtok(nullptr, ","); }
    }

    top = new Vsmstang_top;
    sms = top->smstang_top;
    sms->reset = 1;
    top->joy1 = 0;
    top->joy2 = 0;
    load_rom(rompath);
    sms->reset = 0;

    char path[1024];
    snprintf(path, sizeof path, "%s.log", tag);
    FILE *flog = fopen(path, "w");
    snprintf(path, sizeof path, "%s.aud", tag);
    FILE *faud = fopen(path, "wb");
    setvbuf(flog, NULL, _IOFBF, 1 << 20);

    long frame_count = 0, samples = 0;
    int ce_pix_r = 0;
    bool frame_updated = false;
    uint64_t vhash = 1469598103934665603ULL;
    long frame_nz = 0;
    size_t script_idx = 0;

    while (frame_count < want_frames) {
        step();
        if (sms->ce_pix && !ce_pix_r && sms->x < H_RES && sms->y < V_RES) {
            uint8_t *p = &scr[(sms->y * H_RES + sms->x) * 3];
            p[0] = (sms->color & 0xf) << 4;
            p[1] = sms->color & 0xf0;
            p[2] = (sms->color & 0xf00) >> 4;
            uint32_t px = (p[0] << 16) | (p[1] << 8) | p[2];
            vhash ^= px; vhash *= 1099511628211ULL;
            if (px) frame_nz++;
        }
        ce_pix_r = sms->ce_pix;
        if (sim_time % (53693175 * 2 / 48000) == 0 && !sms->reset) {
            uint16_t al = sms->audio_l, ar = sms->audio_r;
            fwrite(&al, 2, 1, faud); fwrite(&ar, 2, 1, faud);
            samples++;
        }
        if (sms->VS) {
            if (!frame_updated) {
                frame_updated = true;
                fprintf(flog, "F %ld samp=%ld vhash=%016lx nz=%ld\n",
                        frame_count, samples, (unsigned long)vhash, frame_nz);
                if (frame_count < 10000 && dumpall[frame_count]) {
                    snprintf(path, sizeof path, "%s_f%ld.ppm", tag, frame_count);
                    FILE *pf = fopen(path, "wb");
                    if (pf) {
                        fprintf(pf, "P6\n%d %d\n255\n", H_RES, V_RES);
                        fwrite(scr, 1, sizeof scr, pf);
                        fclose(pf);
                    }
                }
                vhash = 1469598103934665603ULL;
                frame_nz = 0;
                memset(scr, 0, sizeof scr);
                frame_count++;
                if (frame_count % 100 == 0) { fprintf(stderr, "frame %ld\n", frame_count); fflush(flog); }
            }
        } else frame_updated = false;
        while (script_idx < script.size() && script[script_idx].first <= frame_count)
            script_idx++;
        if (script_idx > 0 && script_idx <= script.size()) {
            top->joy1 = script[script_idx - 1].second & 0xFFF;
            top->joy2 = 0;
        }
    }
    fprintf(flog, "END frames=%ld samples=%ld\n", frame_count, samples);
    printf("done: frames=%ld samples=%ld sim_time=%lu\n",
           frame_count, samples, (unsigned long)sim_time);
    fclose(flog); fclose(faud);
    return 0;
}

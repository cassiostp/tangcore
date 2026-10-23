// NES smoke capture (Verilator, headless).
//
// Full nestang_top model (VERILATOR branch, verilator/sdram_sim.v) with the
// ROM streamed through the real GameData/GameLoader path. Scripted joypad
// input from a frame script; per-frame video hash + PPM dumps at selected
// frames (raw 6-bit color indices, palette applied offline); audio dump
// decimated to ~48 kHz; 8 KB battery-RAM window at end.
//
// Usage:
//   Vnestang_smoke -m <max_clk> -o <outprefix> [-i script] [-d f0,f1,..]
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <vector>
#include <utility>

#include "Vnestang_smoke.h"
#include "Vnestang_smoke_nestang_top.h"
#include "Vnestang_smoke_NES.h"
#include "verilated.h"

#ifndef TANGCORE_SIM_THREADS
#define TANGCORE_SIM_THREADS 1
#endif

#define PX_W 256
#define PX_H 240

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::threadContextp()->threads(TANGCORE_SIM_THREADS);
    fprintf(stderr, "model threads: %u\n", Verilated::threadContextp()->threads());
    uint64_t max_clk = 0;
    const char *outprefix = "smoke";
    const char *scriptpath = nullptr;
    std::vector<unsigned long long> dumps;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-m") == 0 && i + 1 < argc)
            max_clk = strtoull(argv[++i], nullptr, 10);
        else if (strcmp(argv[i], "-o") == 0 && i + 1 < argc)
            outprefix = argv[++i];
        else if (strcmp(argv[i], "-i") == 0 && i + 1 < argc)
            scriptpath = argv[++i];
        else if (strcmp(argv[i], "-d") == 0 && i + 1 < argc) {
            char *list = argv[++i], *tok = strtok(list, ",");
            while (tok) { dumps.push_back(strtoull(tok, nullptr, 10)); tok = strtok(nullptr, ","); }
        }
    }
    if (max_clk == 0) {
        printf("Usage: %s -m <max_clk> [-o prefix] [-i script] [-d f0,f1,..]\n", argv[0]);
        return 1;
    }
    std::vector<std::pair<uint64_t, uint16_t>> script;
    if (scriptpath) {
        FILE *sf = fopen(scriptpath, "r");
        if (!sf) { printf("cannot open script %s\n", scriptpath); return 1; }
        unsigned long long fr; unsigned int btn;
        while (fscanf(sf, "%llu %x", &fr, &btn) == 2)
            script.push_back({fr, (uint16_t)btn});
        fclose(sf);
        printf("script: %zu entries\n", script.size());
    }

    Vnestang_smoke *top = new Vnestang_smoke;
    Vnestang_smoke_nestang_top *nes = top->nestang_top;
    auto *core = nes->nes;
    char path[1024];
    snprintf(path, sizeof path, "%s.log", outprefix);
    FILE *f = fopen(path, "w");
    snprintf(path, sizeof path, "%s.aud", outprefix);
    FILE *fa = fopen(path, "wb");
    if (!f || !fa) { printf("cannot open outputs\n"); return 1; }
    setvbuf(f, NULL, _IOFBF, 1 << 20);
    setvbuf(fa, NULL, _IOFBF, 1 << 20);

    top->sys_clk = 0;
    top->s1 = 1;
    top->reset2 = 1;
    top->UART_RXD = 1;
    top->eval();

    static uint8_t fb[PX_W * PX_H];
    memset(fb, 0, sizeof fb);

    uint64_t clk = 0, nsamp = 0, frames = 0;
    int prev_scan = -1, last_cy = -1, last_sc = -1;
    uint64_t vhash = 1469598103934665603ULL;
    uint64_t frame_nonzero = 0;
    size_t script_idx = 0;

    while (clk < max_clk) {
        top->sys_clk = 0; top->eval();
        top->sys_clk = 1; top->eval();
        clk++;
        int cy = core->cycle, sc = core->scanline;
        if ((cy != last_cy || sc != last_sc) && cy < PX_W && sc < PX_H) {
            uint8_t px = core->color & 0x3F;
            vhash ^= (uint64_t)px;
            vhash *= 1099511628211ULL;
            fb[sc * PX_W + cy] = px;
            if (px != 0x0F) frame_nonzero++;  // $0F = black
            last_cy = cy; last_sc = sc;
        }
        // ~48 kHz audio decimation (clk/448 at 21.477 MHz)
        if ((clk % 448) == 0) {
            int16_t s = (int16_t)(nes->tb_sample ^ 0x8000);
            fwrite(&s, 2, 1, fa);
            nsamp++;
        }
        if (prev_scan >= 0 && sc < prev_scan && prev_scan > 200) {
            fprintf(f, "F %lu clk=%lu samp=%lu vhash=%016lx nz=%lu joy=%03x map=%02x run=%d\n",
                    (unsigned long)frames, (unsigned long)clk, (unsigned long)nsamp,
                    (unsigned long)vhash, (unsigned long)frame_nonzero,
                    (unsigned)nes->tb_joy1,
                    (unsigned)(nes->__PVT__mapper_flags & 0xFF),
                    (int)!nes->__PVT__reset_nes);
            for (auto df : dumps) {
                if (df == frames) {
                    snprintf(path, sizeof path, "%s_f%lu.ppm", outprefix, (unsigned long)frames);
                    FILE *pf = fopen(path, "wb");
                    if (pf) {
                        fprintf(pf, "P6\n%d %d\n255\n", PX_W, PX_H);
                        for (int i = 0; i < PX_W * PX_H; i++) {
                            // raw index replicated; palette applied offline
                            uint8_t g[3] = {fb[i], fb[i], fb[i]};
                            fwrite(g, 1, 3, pf);
                        }
                        fclose(pf);
                    }
                }
            }
            vhash = 1469598103934665603ULL;
            frame_nonzero = 0;
            frames++;
            while (script_idx < script.size() && script[script_idx].first <= frames) {
                nes->tb_joy1 = script[script_idx].second;
                script_idx++;
            }
            if (frames % 300 == 0)
                printf("clk=%lu frames=%lu samples=%lu\n",
                       (unsigned long)clk, (unsigned long)frames, (unsigned long)nsamp);
        }
        prev_scan = sc;
    }
    // battery-RAM window: 8 KB at linear 0x3C0000 in the SDRAM model
    snprintf(path, sizeof path, "%s_save.bin", outprefix);
    FILE *fsv = fopen(path, "wb");
    uint64_t sh = 1469598103934665603ULL;
    for (uint32_t a = 0; a < 8192; a++) {
        uint8_t b = nes->__PVT__sdram__DOT__mem_cpu[0x3C0000 + a];
        if (fsv) fwrite(&b, 1, 1, fsv);
        sh ^= b; sh *= 1099511628211ULL;
    }
    if (fsv) fclose(fsv);
    fprintf(f, "END clk=%lu frames=%lu samples=%lu save=%016lx\n",
            (unsigned long)clk, (unsigned long)frames, (unsigned long)nsamp, (unsigned long)sh);
    printf("done: clk=%lu frames=%lu samples=%lu save=%016lx\n",
           (unsigned long)clk, (unsigned long)frames, (unsigned long)nsamp, (unsigned long)sh);
    fclose(f); fclose(fa);
    delete top;
    return 0;
}

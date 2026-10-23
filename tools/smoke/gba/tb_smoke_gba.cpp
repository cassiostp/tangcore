// Headless full-core sound probe: loads a ROM like verilator/sim_main.cpp,
// runs N frames with scripted A presses, logs sound/timer/DMA MMIO writes,
// per-frame FIFO + PSG aggregates, and dumps 48 kHz audio (s16le stereo).
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <map>
#include "Vgbatang_top.h"
#include "Vgbatang_top___024root.h"
#include "Vgbatang_top_gbatang_top.h"
#include "verilated.h"

#ifndef TANGCORE_SIM_THREADS
#define TANGCORE_SIM_THREADS 1
#endif

static Vgbatang_top *top;
static Vgbatang_top_gbatang_top *gba;
static uint64_t sim_time = 0;
static uint8_t clkcnt = 0;
static bool posedge16 = false;
static int clk16_last = 0;

static inline void step() {
    clkcnt = clkcnt == 5 ? 0 : clkcnt + 1;
    top->clk50 = clkcnt & 1;
    top->clk16 = clkcnt >= 3;
    top->eval();
    sim_time++;
    posedge16 = (top->clk16 == 1 && clk16_last == 0);
    clk16_last = top->clk16;
}
static inline void step_clk16() { do step(); while (!posedge16); }

static const int BACKUP_NONE=0, BACKUP_FLASH512K=1, BACKUP_FLASH1M=2, BACKUP_SRAM=3, BACKUP_EEPROM=4;
static int detect_backup_type(uint8_t *rom, int size) {
    for (int i = 0; i < size-4; i+=4) {
        char *p = (char *)rom+i;
        if (strncmp(p, "EEPROM_V", 8) == 0) return BACKUP_EEPROM;
        if (strncmp(p, "FLASH_V", 7) == 0) return BACKUP_FLASH512K;
        if (strncmp(p, "FLASH512_V", 10) == 0) return BACKUP_FLASH512K;
        if (strncmp(p, "FLASH1M_V", 9) == 0) return BACKUP_FLASH1M;
        if (strncmp(p, "SRAM_V", 6) == 0) return BACKUP_SRAM;
        if (strncmp(p, "SRAM_F_V", 8) == 0) return BACKUP_SRAM;
    }
    return BACKUP_NONE;
}

static void gba_load(uint8_t *rom, int size, int backup_type) {
    // Fast load: poke sdram_sim mem directly (ROM word i at mem[i], cartRAM
    // at FLASH_BASE word 8454144, per gba_memory tosdram()), then walk the
    // loader state machine 1 -> 2 -> 3 (backup byte) -> 0 with no payload.
    while (sim_time < 10 || !posedge16) step();
    top->loading = 1;
    for (int i = 0; i < 20; i++) step_clk16();
    auto &mem = gba->__PVT__sdram__DOT__mem;
    for (int i = 0; i + 4 <= size; i += 4)
        mem[i/4] = rom[i] | (rom[i+1]<<8) | (rom[i+2]<<16) | ((uint32_t)rom[i+3]<<24);
    uint32_t fill = (backup_type==BACKUP_SRAM||backup_type==BACKUP_FLASH512K||backup_type==BACKUP_FLASH1M) ? 0xffffffffu : 0;
    for (int i = 0; i < 128*1024/4; i++) mem[8454144 + i] = fill;
    top->loading = 2;
    for (int i = 0; i < 20; i++) step_clk16();
    top->loading = 3;
    step_clk16(); top->loader_do_valid = 1; top->loader_do = backup_type;
    step_clk16(); top->loader_do_valid = 0;
    for (int i = 0; i < 10; i++) step_clk16();
    top->loading = 0;
    for (int i = 0; i < 10; i++) step_clk16();
}

// ---- probe state ----
static FILE *flog, *faud;
static uint8_t scr[240*160*3];
static char tagbuf[256];
static void dump_ppm(long fr) {
    char b[300]; snprintf(b, sizeof b, "%s_f%ld.ppm", tagbuf, fr);
    FILE *pf = fopen(b, "wb"); if (!pf) return;
    fprintf(pf, "P6\n240 160\n255\n"); fwrite(scr, 1, sizeof scr, pf); fclose(pf);
}
static long frame_count = 0;
static bool frame_updated = false;
// per-frame aggregates
static long f_fifoA_wr, f_fifoB_wr, f_advA, f_advB, f_undA, f_undB, f_reqA, f_reqB;
static int f_minA, f_maxA, f_minB, f_maxB;
static long f_chon[4], f_wrap[4], f_clks;
static std::map<int,long> divhist[4];     // freq_divider -> clks while ch_on (ch4: freq_divider)
static long tot_wrap[4] = {0,0,0,0};
static long stat_from_frame = 600;

static uint8_t prev_afcA=0, prev_afcB=0, prev_baseA=0, prev_baseB=0, prev_reqA=0, prev_reqB=0;
static uint32_t prev_fifowrA=0, prev_fifowrB=0;
static uint8_t prev_ptr[4] = {0,0,0,0};

static void frame_reset() {
    f_fifoA_wr=f_fifoB_wr=f_advA=f_advB=f_undA=f_undB=f_reqA=f_reqB=0;
    f_minA=f_minB=99; f_maxA=f_maxB=-1;
    for (int i=0;i<4;i++){f_chon[i]=0;f_wrap[i]=0;}
    f_clks=0;
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::threadContextp()->threads(TANGCORE_SIM_THREADS);
    fprintf(stderr, "model threads: %u\n", Verilated::threadContextp()->threads());
    if (argc < 4) { fprintf(stderr, "usage: probe <rom> <frames> <tag> [dumplist]\n"); return 1; }
    const char *rompath = argv[1];
    long want_frames = atol(argv[2]);
    const char *tag = argv[3];
    // optional dump frames "60,300,600" (default: 599 of every 600)
    long dumps[64]; int ndumps = 0;
    if (argc > 4) {
        char *list = argv[4], *tok = strtok(list, ",");
        while (tok && ndumps < 64) { dumps[ndumps++] = atol(tok); tok = strtok(nullptr, ","); }
    }
    char buf[256];
    snprintf(tagbuf, sizeof tagbuf, "%s", tag);
    snprintf(buf, sizeof buf, "%s.log", tag); flog = fopen(buf, "w");
    snprintf(buf, sizeof buf, "%s.aud", tag); faud = fopen(buf, "wb");

    top = new Vgbatang_top;
    gba = top->gbatang_top;

    FILE *f = fopen(rompath, "rb");
    if (!f) { fprintf(stderr, "cannot open %s\n", rompath); return 1; }
    fseek(f, 0, SEEK_END); long size = ftell(f); fseek(f, 0, SEEK_SET);
    uint8_t *rom = (uint8_t*)malloc(size);
    if (fread(rom, 1, size, f) != (size_t)size) return 1;
    fclose(f);
    int bt = detect_backup_type(rom, size);
    fprintf(flog, "# rom size=%ld backup=%d\n", size, bt);
    gba_load(rom, size, bt);
    free(rom);
    sim_time = 0;
    frame_reset();

    long long samples = 0;
    setvbuf(flog, NULL, _IOLBF, 0);
    uint64_t dbg_last = 0; int dbg_maxx = 0, dbg_maxy = 0;
    while (frame_count < want_frames) {
        step();
        if (sim_time - dbg_last >= 20000000ULL) {
            dbg_last = sim_time;
            fprintf(stderr, "t=%llu frames=%ld gba_on=%d maxx=%d maxy=%d pwe=%d ram=%08x\n",
                (unsigned long long)sim_time, frame_count, (int)top->gba_on,
                dbg_maxx, dbg_maxy, (int)gba->pixel_out_we, gba->ram_addr);
            if (sim_time > 400000000ULL && frame_count == 0) { fprintf(stderr, "ABORT no frames\n"); break; }
        }
        if (gba->pixel_out_we) { if (gba->pixel_out_x > dbg_maxx) dbg_maxx = gba->pixel_out_x; if (gba->pixel_out_y > dbg_maxy) dbg_maxy = gba->pixel_out_y; }
        if (gba->pixel_out_we && gba->pixel_out_x < 240 && gba->pixel_out_y < 160) {
            int rgb = gba->pixel_out_data; uint8_t *p = &scr[(gba->pixel_out_y*240 + gba->pixel_out_x)*3];
            p[0] = (rgb >> 12) << 2; p[1] = ((rgb >> 6) & 0x3f) << 2; p[2] = (rgb & 0x3f) << 2;
        }
        // frame end (every step, like sim_main: pixel_out_we pulses off clk16 posedge phase)
        if (gba->pixel_out_we && gba->pixel_out_y == 159 && gba->pixel_out_x == 239) {
            if (!frame_updated) {
                frame_updated = true;
                // FNV-1a over the frame buffer for compare.py
                uint64_t fh = 1469598103934665603ULL;
                long fhnz = 0;
                for (size_t i = 0; i < sizeof scr; i++) {
                    fh ^= scr[i]; fh *= 1099511628211ULL;
                    if (scr[i]) fhnz++;
                }
                fprintf(flog, "F %ld samp=%lld vhash=%016lx nz=%ld clks=%ld fifoA wr=%ld adv=%ld und=%ld req=%ld cnt=[%d..%d] fifoB wr=%ld adv=%ld und=%ld req=%ld cnt=[%d..%d] chon=%ld,%ld,%ld,%ld wrap=%ld,%ld,%ld div=%d,%d,%d,%d\n",
                    frame_count, samples, (unsigned long)fh, fhnz, f_clks, f_fifoA_wr, f_advA, f_undA, f_reqA, f_minA, f_maxA,
                    f_fifoB_wr, f_advB, f_undB, f_reqB, f_minB, f_maxB,
                    f_chon[0],f_chon[1],f_chon[2],f_chon[3], f_wrap[0],f_wrap[1],f_wrap[2],
                    (int)gba->__PVT__sound__DOT__igba_sound_ch1__DOT__freq_divider,
                    (int)gba->__PVT__sound__DOT__igba_sound_ch2__DOT__freq_divider,
                    (int)gba->__PVT__sound__DOT__igba_sound_ch3__DOT__freq_divider,
                    (int)gba->__PVT__sound__DOT__igba_sound_ch4__DOT__freq_divider);
                frame_reset();
                bool dump = false;
                if (ndumps) { for (int i = 0; i < ndumps; i++) if (dumps[i] == frame_count) dump = true; }
                else dump = (frame_count % 600 == 599);
                if (dump) dump_ppm(frame_count);
                frame_count++;
                if (frame_count % 100 == 0) { fprintf(stderr, "frame %ld\n", frame_count); fflush(flog); }
            }
        } else frame_updated = false;
        if (!posedge16) continue;
        f_clks++;

        // buttons: A (bit8) held 10 frames every 120 frames; Start (bit3) once at 900..910
        top->joy_btns = 0;
        if ((frame_count % 120) >= 60 && (frame_count % 120) < 70) top->joy_btns |= (1<<8);
        if (frame_count >= 900 && frame_count < 910) top->joy_btns |= (1<<3);

        // CPU MMIO writes: IO region offsets of interest (sound 60-A8, DMA B0-E0, timers 100-110)
        if (gba->ram_cen & gba->ram_wen) {
            uint32_t a = gba->ram_addr;
            uint32_t off = a & 0x3FFFF;
            if ((a >> 24) == 4 && ((off >= 0x60 && off < 0xE4) || (off >= 0x100 && off < 0x114))) {
                fprintf(flog, "W f=%ld t=%llu a=%08x d=%08x be=%x\n", frame_count,
                        (unsigned long long)sim_time, a, gba->ram_wdata, gba->ram_be);
            }
        }
        auto *S = gba; // flattened members live on gbatang_top class
        uint8_t fcA = S->__PVT__sound__DOT__igba_sound_dmaA__DOT__fifo_cnt;
        uint8_t fcB = S->__PVT__sound__DOT__igba_sound_dmaB__DOT__fifo_cnt;
        uint8_t afcA = S->__PVT__sound__DOT__igba_sound_dmaA__DOT__afterfifo_cnt;
        uint8_t afcB = S->__PVT__sound__DOT__igba_sound_dmaB__DOT__afterfifo_cnt;
        uint8_t baseA = S->__PVT__sound__DOT__igba_sound_dmaA__DOT__fifo_base;
        uint8_t baseB = S->__PVT__sound__DOT__igba_sound_dmaB__DOT__fifo_base;
        uint8_t rqA = S->__PVT__sound__DOT__igba_sound_dmaA__DOT__new_sample_request;
        uint8_t rqB = S->__PVT__sound__DOT__igba_sound_dmaB__DOT__new_sample_request;
        uint32_t fwA = S->__PVT__sound__DOT__igba_sound_dmaA__DOT__FIFO_REGISTER_written;
        uint32_t fwB = S->__PVT__sound__DOT__igba_sound_dmaB__DOT__FIFO_REGISTER_written;
        if (fwA && !prev_fifowrA) f_fifoA_wr++;
        if (fwB && !prev_fifowrB) f_fifoB_wr++;
        if (rqA && !prev_reqA) f_reqA++;
        if (rqB && !prev_reqB) f_reqB++;
        bool advA = (afcA != prev_afcA) || (baseA != prev_baseA);
        bool advB = (afcB != prev_afcB) || (baseB != prev_baseB);
        if (advA) f_advA++; if (advB) f_advB++;
        if (prev_reqA && !rqA && !advA && !fwA) f_undA++;
        if (prev_reqB && !rqB && !advB && !fwB) f_undB++;
        if (fcA < f_minA) f_minA = fcA; if (fcA > f_maxA) f_maxA = fcA;
        if (fcB < f_minB) f_minB = fcB; if (fcB > f_maxB) f_maxB = fcB;
        prev_afcA=afcA; prev_afcB=afcB; prev_baseA=baseA; prev_baseB=baseB;
        prev_reqA=rqA; prev_reqB=rqB; prev_fifowrA=fwA; prev_fifowrB=fwB;

        // PSG activity + wavetable wraps
        uint8_t ptr[4], on[4];
        int divd[4];
        ptr[0]=S->__PVT__sound__DOT__igba_sound_ch1__DOT__wavetable_ptr; on[0]=S->__PVT__sound__DOT__igba_sound_ch1__DOT__ch_on; divd[0]=S->__PVT__sound__DOT__igba_sound_ch1__DOT__freq_divider;
        ptr[1]=S->__PVT__sound__DOT__igba_sound_ch2__DOT__wavetable_ptr; on[1]=S->__PVT__sound__DOT__igba_sound_ch2__DOT__ch_on; divd[1]=S->__PVT__sound__DOT__igba_sound_ch2__DOT__freq_divider;
        ptr[2]=S->__PVT__sound__DOT__igba_sound_ch3__DOT__wavetable_ptr; on[2]=S->__PVT__sound__DOT__igba_sound_ch3__DOT__ch_on; divd[2]=S->__PVT__sound__DOT__igba_sound_ch3__DOT__freq_divider;
        ptr[3]=0; on[3]=S->__PVT__sound__DOT__igba_sound_ch4__DOT__ch_on; divd[3]=(int)S->__PVT__sound__DOT__igba_sound_ch4__DOT__freq_divider;
        for (int i=0;i<4;i++) {
            if (on[i]) { f_chon[i]++; if (frame_count>=stat_from_frame && (f_clks & 63) == 0) divhist[i][divd[i]]++; }
            if (i<3) {
                int topv = (i==2)?31:7;
                if (prev_ptr[i]==topv && ptr[i]==0 && on[i]) { f_wrap[i]++; if (frame_count>=stat_from_frame) tot_wrap[i]++; }
            }
            prev_ptr[i]=ptr[i];
        }

        // audio dump @48k (same cadence as sim_main)
        if (sim_time % (16777216 * 6 / 48000) == 0 && top->gba_on) {
            uint16_t al = gba->sound_out_left, ar = gba->sound_out_right;
            fwrite(&al, 2, 1, faud); fwrite(&ar, 2, 1, faud); samples++;
        }

    }
    fprintf(flog, "# done frames=%ld samples=%lld\n", frame_count, samples);
    fprintf(flog, "END frames=%ld samples=%lld\n", frame_count, samples);
    // backup image: 128 KB cartRAM at SDRAM word 8454144 (see gba_load)
    {
        char sb[300]; snprintf(sb, sizeof sb, "%s_save.bin", tagbuf);
        FILE *fs = fopen(sb, "wb");
        uint64_t sh = 1469598103934665603ULL;
        auto &mem = gba->__PVT__sdram__DOT__mem;
        for (int i = 0; i < 128*1024/4; i++) {
            uint32_t w = mem[8454144 + i];
            uint8_t b[4] = {(uint8_t)w, (uint8_t)(w>>8), (uint8_t)(w>>16), (uint8_t)(w>>24)};
            if (fs) fwrite(b, 1, 4, fs);
            for (int k = 0; k < 4; k++) { sh ^= b[k]; sh *= 1099511628211ULL; }
        }
        if (fs) fclose(fs);
        fprintf(flog, "# save hash=%016lx\n", (unsigned long)sh);
    }
    for (int i=0;i<3;i++) {
        fprintf(flog, "# ch%d wraps(>=f%ld)=%ld top dividers:", i+1, stat_from_frame, tot_wrap[i]);
        // print top-5 dividers by clks
        for (int k=0;k<5;k++) {
            long best=0; int bd=-1;
            for (auto &kv : divhist[i]) if (kv.second>best) { /* skip printed via erase */ }
            // simple: find max then erase
            auto it = divhist[i].begin(); auto bit = it;
            for (it = divhist[i].begin(); it != divhist[i].end(); ++it) if (it->second > best) { best=it->second; bd=it->first; bit=it; }
            if (bd<0) break;
            fprintf(flog, " %d:%ld", bd, best);
            divhist[i].erase(bit);
        }
        fprintf(flog, "\n");
    }
    fclose(flog); fclose(faud);
    return 0;
}

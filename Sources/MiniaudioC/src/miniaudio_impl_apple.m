// Objective-C compilation unit for MiniAudio on Apple platforms.
// AVFoundation headers require Objective-C; this file provides that
// while miniaudio_impl.c handles non-Apple platforms.

#if defined(__APPLE__)
#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"
#endif

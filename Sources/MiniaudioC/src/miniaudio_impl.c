// On Apple platforms, MiniAudio is compiled from miniaudio_impl_apple.m
// because AVFoundation headers require Objective-C.
#if !defined(__APPLE__)
#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"
#endif

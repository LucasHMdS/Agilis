#ifdef __APPLE__

#include "platform.h"
#import <Cocoa/Cocoa.h>
#include <stdlib.h>
#include <string.h>

// ---- GLFW Key Code Constants ----

#define AGILIS_KEY_SPACE        32
#define AGILIS_KEY_0            48
#define AGILIS_KEY_9            57
#define AGILIS_KEY_A            65
#define AGILIS_KEY_Z            90
#define AGILIS_KEY_ESCAPE       256
#define AGILIS_KEY_ENTER        257
#define AGILIS_KEY_TAB          258
#define AGILIS_KEY_BACKSPACE    259
#define AGILIS_KEY_INSERT       260
#define AGILIS_KEY_DELETE       261
#define AGILIS_KEY_RIGHT        262
#define AGILIS_KEY_LEFT         263
#define AGILIS_KEY_DOWN         264
#define AGILIS_KEY_UP           265
#define AGILIS_KEY_F1           290
#define AGILIS_KEY_F12          301
#define AGILIS_KEY_LEFT_SHIFT   340
#define AGILIS_KEY_LEFT_CONTROL 341
#define AGILIS_KEY_LEFT_ALT     342
#define AGILIS_KEY_RIGHT_SHIFT  344
#define AGILIS_KEY_RIGHT_CONTROL 345
#define AGILIS_KEY_RIGHT_ALT    346

#define MAX_KEYS 512
#define MAX_MOUSE_BUTTONS 3
#define MAX_GAMEPADS 4

// ---- macOS Virtual Key Code -> GLFW Key Mapping ----

static int macos_keycode_to_agilis(unsigned short keyCode) {
    // Carbon kVK_* key codes
    switch (keyCode) {
        case 0x00: return AGILIS_KEY_A;
        case 0x01: return AGILIS_KEY_A + ('S' - 'A');
        case 0x02: return AGILIS_KEY_A + ('D' - 'A');
        case 0x03: return AGILIS_KEY_A + ('F' - 'A');
        case 0x04: return AGILIS_KEY_A + ('H' - 'A');
        case 0x05: return AGILIS_KEY_A + ('G' - 'A');
        case 0x06: return AGILIS_KEY_A + ('Z' - 'A');
        case 0x07: return AGILIS_KEY_A + ('X' - 'A');
        case 0x08: return AGILIS_KEY_A + ('C' - 'A');
        case 0x09: return AGILIS_KEY_A + ('V' - 'A');
        case 0x0B: return AGILIS_KEY_A + ('B' - 'A');
        case 0x0C: return AGILIS_KEY_A + ('Q' - 'A');
        case 0x0D: return AGILIS_KEY_A + ('W' - 'A');
        case 0x0E: return AGILIS_KEY_A + ('E' - 'A');
        case 0x0F: return AGILIS_KEY_A + ('R' - 'A');
        case 0x10: return AGILIS_KEY_A + ('Y' - 'A');
        case 0x11: return AGILIS_KEY_A + ('T' - 'A');
        case 0x12: return AGILIS_KEY_0 + 1;
        case 0x13: return AGILIS_KEY_0 + 2;
        case 0x14: return AGILIS_KEY_0 + 3;
        case 0x15: return AGILIS_KEY_0 + 4;
        case 0x16: return AGILIS_KEY_0 + 6;
        case 0x17: return AGILIS_KEY_0 + 5;
        case 0x19: return AGILIS_KEY_0 + 9;
        case 0x1A: return AGILIS_KEY_0 + 7;
        case 0x1C: return AGILIS_KEY_0 + 8;
        case 0x1D: return AGILIS_KEY_0;
        case 0x1E: return AGILIS_KEY_A + ('O' - 'A');
        case 0x1F: return AGILIS_KEY_A + ('U' - 'A');
        case 0x20: return AGILIS_KEY_A + ('I' - 'A');
        case 0x22: return AGILIS_KEY_A + ('P' - 'A');
        case 0x23: return AGILIS_KEY_A + ('L' - 'A');
        case 0x25: return AGILIS_KEY_A + ('J' - 'A');
        case 0x26: return AGILIS_KEY_A + ('K' - 'A');
        case 0x28: return AGILIS_KEY_A + ('N' - 'A');
        case 0x29: return AGILIS_KEY_A + ('M' - 'A');
        case 0x24: return AGILIS_KEY_ENTER;
        case 0x30: return AGILIS_KEY_TAB;
        case 0x31: return AGILIS_KEY_SPACE;
        case 0x33: return AGILIS_KEY_BACKSPACE;
        case 0x35: return AGILIS_KEY_ESCAPE;
        case 0x75: return AGILIS_KEY_DELETE;
        case 0x7A: return AGILIS_KEY_F1;
        case 0x78: return AGILIS_KEY_F1 + 1;
        case 0x63: return AGILIS_KEY_F1 + 2;
        case 0x76: return AGILIS_KEY_F1 + 3;
        case 0x60: return AGILIS_KEY_F1 + 4;
        case 0x61: return AGILIS_KEY_F1 + 5;
        case 0x62: return AGILIS_KEY_F1 + 6;
        case 0x64: return AGILIS_KEY_F1 + 7;
        case 0x65: return AGILIS_KEY_F1 + 8;
        case 0x6D: return AGILIS_KEY_F1 + 9;
        case 0x67: return AGILIS_KEY_F1 + 10;
        case 0x6F: return AGILIS_KEY_F1 + 11;
        case 0x7E: return AGILIS_KEY_UP;
        case 0x7D: return AGILIS_KEY_DOWN;
        case 0x7B: return AGILIS_KEY_LEFT;
        case 0x7C: return AGILIS_KEY_RIGHT;
        case 0x38: return AGILIS_KEY_LEFT_SHIFT;
        case 0x3C: return AGILIS_KEY_RIGHT_SHIFT;
        case 0x3B: return AGILIS_KEY_LEFT_CONTROL;
        case 0x3E: return AGILIS_KEY_RIGHT_CONTROL;
        case 0x3A: return AGILIS_KEY_LEFT_ALT;
        case 0x3D: return AGILIS_KEY_RIGHT_ALT;
        default: return -1;
    }
}

// ---- Platform Window ----

struct PlatformWindow {
    NSWindow* ns_window;
    NSView* ns_view;
    bool should_close;
    bool resized;
    int width;
    int height;

    bool keys[MAX_KEYS];
    uint32_t char_pressed;

    bool mouse_buttons[MAX_MOUSE_BUTTONS];
    float mouse_x, mouse_y;
    float mouse_dx, mouse_dy;
    float mouse_scroll;
    float prev_mouse_x, prev_mouse_y;
    bool mouse_initialized;

    int target_fps;
    bool vsync;
};

// ---- Cocoa Delegate ----

@interface AgilisWindowDelegate : NSObject <NSWindowDelegate>
@property (nonatomic, assign) PlatformWindow* platform;
@end

@implementation AgilisWindowDelegate
- (BOOL)windowShouldClose:(id)sender {
    self.platform->should_close = true;
    return NO;
}

- (void)windowDidResize:(NSNotification *)notification {
    NSRect frame = [self.platform->ns_view frame];
    self.platform->width = (int)frame.size.width;
    self.platform->height = (int)frame.size.height;
    self.platform->resized = true;
}
@end

// Global state for the delegate (prevent ARC from releasing it)
static AgilisWindowDelegate* g_delegate = nil;

// ---- Window Lifecycle ----

PlatformWindow* platform_create_window(const PlatformWindowConfig* config) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

        PlatformWindow* w = (PlatformWindow*)calloc(1, sizeof(PlatformWindow));
        if (!w) return NULL;

        NSUInteger styleMask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable;
        if (config->resizable)
            styleMask |= NSWindowStyleMaskResizable;

        NSRect rect = NSMakeRect(0, 0, config->width, config->height);
        NSString* title = [NSString stringWithUTF8String:config->title];

        w->ns_window = [[NSWindow alloc] initWithContentRect:rect
                                                   styleMask:styleMask
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
        [w->ns_window setTitle:title];
        [w->ns_window center];

        g_delegate = [[AgilisWindowDelegate alloc] init];
        g_delegate.platform = w;
        [w->ns_window setDelegate:g_delegate];

        w->ns_view = [w->ns_window contentView];
        w->width = config->width;
        w->height = config->height;
        w->target_fps = config->target_fps;
        w->vsync = config->vsync;

        [w->ns_window makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];

        // Process initial events
        NSEvent* event;
        while ((event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                           untilDate:[NSDate distantPast]
                                              inMode:NSDefaultRunLoopMode
                                             dequeue:YES])) {
            [NSApp sendEvent:event];
        }

        return w;
    }
}

void platform_destroy_window(PlatformWindow* w) {
    if (!w) return;
    @autoreleasepool {
        [w->ns_window close];
        g_delegate = nil;
        free(w);
    }
}

bool platform_should_close(PlatformWindow* w) {
    return w ? w->should_close : true;
}

void platform_poll_events(PlatformWindow* w) {
    if (!w) return;
    @autoreleasepool {
        // Compute mouse delta
        if (w->mouse_initialized) {
            w->mouse_dx = w->mouse_x - w->prev_mouse_x;
            w->mouse_dy = w->mouse_y - w->prev_mouse_y;
        } else {
            w->mouse_dx = 0;
            w->mouse_dy = 0;
            w->mouse_initialized = true;
        }
        w->prev_mouse_x = w->mouse_x;
        w->prev_mouse_y = w->mouse_y;

        w->mouse_scroll = 0;
        w->char_pressed = 0;
        w->resized = false;

        NSEvent* event;
        while ((event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                           untilDate:[NSDate distantPast]
                                              inMode:NSDefaultRunLoopMode
                                             dequeue:YES])) {
            switch ([event type]) {
                case NSEventTypeKeyDown: {
                    int key = macos_keycode_to_agilis([event keyCode]);
                    if (key >= 0 && key < MAX_KEYS)
                        w->keys[key] = true;
                    NSString* chars = [event characters];
                    if ([chars length] > 0) {
                        unichar ch = [chars characterAtIndex:0];
                        if (ch >= 32)
                            w->char_pressed = (uint32_t)ch;
                    }
                    break;
                }
                case NSEventTypeKeyUp: {
                    int key = macos_keycode_to_agilis([event keyCode]);
                    if (key >= 0 && key < MAX_KEYS)
                        w->keys[key] = false;
                    break;
                }
                case NSEventTypeLeftMouseDown:  w->mouse_buttons[0] = true; break;
                case NSEventTypeLeftMouseUp:    w->mouse_buttons[0] = false; break;
                case NSEventTypeRightMouseDown: w->mouse_buttons[1] = true; break;
                case NSEventTypeRightMouseUp:   w->mouse_buttons[1] = false; break;
                case NSEventTypeOtherMouseDown: w->mouse_buttons[2] = true; break;
                case NSEventTypeOtherMouseUp:   w->mouse_buttons[2] = false; break;
                case NSEventTypeMouseMoved:
                case NSEventTypeLeftMouseDragged:
                case NSEventTypeRightMouseDragged:
                case NSEventTypeOtherMouseDragged: {
                    NSPoint loc = [event locationInWindow];
                    NSRect frame = [w->ns_view frame];
                    w->mouse_x = (float)loc.x;
                    w->mouse_y = (float)(frame.size.height - loc.y); // Flip Y
                    break;
                }
                case NSEventTypeScrollWheel:
                    w->mouse_scroll = (float)[event scrollingDeltaY];
                    break;
                default:
                    break;
            }
            [NSApp sendEvent:event];
        }
    }
}

int platform_window_width(PlatformWindow* w) { return w ? w->width : 0; }
int platform_window_height(PlatformWindow* w) { return w ? w->height : 0; }
bool platform_window_resized(PlatformWindow* w) { return w ? w->resized : false; }

// ---- EGL Surface Hooks ----

void* platform_native_display(PlatformWindow* w) {
    // EGL_DEFAULT_DISPLAY for macOS (ANGLE uses Metal backend)
    return NULL;
}

void* platform_native_window(PlatformWindow* w) {
    if (!w) return NULL;
    return (__bridge void*)[w->ns_view layer];
}

// ---- Keyboard ----

bool platform_is_key_down(PlatformWindow* w, int key) {
    if (!w || key < 0 || key >= MAX_KEYS) return false;
    return w->keys[key];
}

uint32_t platform_char_pressed(PlatformWindow* w) {
    return w ? w->char_pressed : 0;
}

// ---- Mouse ----

bool platform_is_mouse_button_down(PlatformWindow* w, int button) {
    if (!w || button < 0 || button >= MAX_MOUSE_BUTTONS) return false;
    return w->mouse_buttons[button];
}

float platform_mouse_x(PlatformWindow* w) { return w ? w->mouse_x : 0; }
float platform_mouse_y(PlatformWindow* w) { return w ? w->mouse_y : 0; }
float platform_mouse_dx(PlatformWindow* w) { return w ? w->mouse_dx : 0; }
float platform_mouse_dy(PlatformWindow* w) { return w ? w->mouse_dy : 0; }
float platform_mouse_scroll(PlatformWindow* w) { return w ? w->mouse_scroll : 0; }

// ---- Gamepad (stub — TODO: GCController / IOKit HID) ----

bool platform_is_gamepad_available(int index) { return false; }
bool platform_is_gamepad_button_down(int index, int button) { return false; }
float platform_gamepad_axis(int index, int axis) { return 0; }
const char* platform_gamepad_name(int index) { return NULL; }

// ---- Frame Timing ----

void platform_set_target_fps(PlatformWindow* w, int fps) {
    if (w) w->target_fps = fps;
}

void platform_set_vsync(PlatformWindow* w, bool enabled) {
    if (w) w->vsync = enabled;
}

#endif // __APPLE__

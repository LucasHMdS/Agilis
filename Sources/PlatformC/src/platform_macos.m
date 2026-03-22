#if defined(__APPLE__)
#include <TargetConditionals.h>
#if !TARGET_OS_IOS && !TARGET_OS_TV && !TARGET_OS_WATCH

#include "platform.h"
#import <Cocoa/Cocoa.h>
#import <GameController/GameController.h>
#include <stdlib.h>
#include <string.h>

// Key constants and limits are defined in platform.h (AGILIS_KEY_*, AGILIS_MAX_*)
#define MAX_GAMEPAD_BUTTONS 18
#define MAX_GAMEPAD_AXES 6

// ---- macOS Virtual Key Code -> USB HID Key Mapping ----
// Carbon kVK_ANSI_* codes are position-based (physical key location),
// not character-based. Order follows the US ANSI keyboard layout.

static int macos_keycode_to_agilis(unsigned short keyCode) {
    switch (keyCode) {
        // Letters (kVK_ANSI_* — non-sequential, physical key positions)
        case 0x00: return AGILIS_KEY_A + ('A' - 'A'); // kVK_ANSI_A
        case 0x01: return AGILIS_KEY_A + ('S' - 'A'); // kVK_ANSI_S
        case 0x02: return AGILIS_KEY_A + ('D' - 'A'); // kVK_ANSI_D
        case 0x03: return AGILIS_KEY_A + ('F' - 'A'); // kVK_ANSI_F
        case 0x04: return AGILIS_KEY_A + ('H' - 'A'); // kVK_ANSI_H
        case 0x05: return AGILIS_KEY_A + ('G' - 'A'); // kVK_ANSI_G
        case 0x06: return AGILIS_KEY_A + ('Z' - 'A'); // kVK_ANSI_Z
        case 0x07: return AGILIS_KEY_A + ('X' - 'A'); // kVK_ANSI_X
        case 0x08: return AGILIS_KEY_A + ('C' - 'A'); // kVK_ANSI_C
        case 0x09: return AGILIS_KEY_A + ('V' - 'A'); // kVK_ANSI_V
        case 0x0B: return AGILIS_KEY_A + ('B' - 'A'); // kVK_ANSI_B
        case 0x0C: return AGILIS_KEY_A + ('Q' - 'A'); // kVK_ANSI_Q
        case 0x0D: return AGILIS_KEY_A + ('W' - 'A'); // kVK_ANSI_W
        case 0x0E: return AGILIS_KEY_A + ('E' - 'A'); // kVK_ANSI_E
        case 0x0F: return AGILIS_KEY_A + ('R' - 'A'); // kVK_ANSI_R
        case 0x10: return AGILIS_KEY_A + ('Y' - 'A'); // kVK_ANSI_Y
        case 0x11: return AGILIS_KEY_A + ('T' - 'A'); // kVK_ANSI_T
        case 0x1F: return AGILIS_KEY_A + ('O' - 'A'); // kVK_ANSI_O
        case 0x20: return AGILIS_KEY_A + ('U' - 'A'); // kVK_ANSI_U
        case 0x22: return AGILIS_KEY_A + ('I' - 'A'); // kVK_ANSI_I
        case 0x23: return AGILIS_KEY_A + ('P' - 'A'); // kVK_ANSI_P
        case 0x25: return AGILIS_KEY_A + ('L' - 'A'); // kVK_ANSI_L
        case 0x26: return AGILIS_KEY_A + ('J' - 'A'); // kVK_ANSI_J
        case 0x28: return AGILIS_KEY_A + ('K' - 'A'); // kVK_ANSI_K
        case 0x2D: return AGILIS_KEY_A + ('N' - 'A'); // kVK_ANSI_N
        case 0x2E: return AGILIS_KEY_A + ('M' - 'A'); // kVK_ANSI_M

        // Numbers (kVK_ANSI_1..9,0 — non-sequential!)
        case 0x12: return AGILIS_KEY_1;       // kVK_ANSI_1
        case 0x13: return AGILIS_KEY_1 + 1;   // kVK_ANSI_2
        case 0x14: return AGILIS_KEY_1 + 2;   // kVK_ANSI_3
        case 0x15: return AGILIS_KEY_1 + 3;   // kVK_ANSI_4
        case 0x17: return AGILIS_KEY_1 + 4;   // kVK_ANSI_5
        case 0x16: return AGILIS_KEY_1 + 5;   // kVK_ANSI_6
        case 0x1A: return AGILIS_KEY_1 + 6;   // kVK_ANSI_7
        case 0x1C: return AGILIS_KEY_1 + 7;   // kVK_ANSI_8
        case 0x19: return AGILIS_KEY_1 + 8;   // kVK_ANSI_9
        case 0x1D: return AGILIS_KEY_0;        // kVK_ANSI_0

        // Special keys
        case 0x24: return AGILIS_KEY_ENTER;     // kVK_Return
        case 0x35: return AGILIS_KEY_ESCAPE;    // kVK_Escape
        case 0x33: return AGILIS_KEY_BACKSPACE; // kVK_Delete (backspace)
        case 0x30: return AGILIS_KEY_TAB;       // kVK_Tab
        case 0x31: return AGILIS_KEY_SPACE;     // kVK_Space

        // Punctuation (kVK_ANSI_*)
        case 0x1B: return AGILIS_KEY_MINUS;          // kVK_ANSI_Minus
        case 0x18: return AGILIS_KEY_EQUAL;           // kVK_ANSI_Equal
        case 0x21: return AGILIS_KEY_LEFT_BRACKET;    // kVK_ANSI_LeftBracket
        case 0x1E: return AGILIS_KEY_RIGHT_BRACKET;   // kVK_ANSI_RightBracket
        case 0x2A: return AGILIS_KEY_BACKSLASH;       // kVK_ANSI_Backslash
        case 0x29: return AGILIS_KEY_SEMICOLON;       // kVK_ANSI_Semicolon
        case 0x27: return AGILIS_KEY_APOSTROPHE;      // kVK_ANSI_Quote
        case 0x32: return AGILIS_KEY_GRAVE;           // kVK_ANSI_Grave
        case 0x2B: return AGILIS_KEY_COMMA;           // kVK_ANSI_Comma
        case 0x2F: return AGILIS_KEY_PERIOD;          // kVK_ANSI_Period
        case 0x2C: return AGILIS_KEY_SLASH;           // kVK_ANSI_Slash

        // Lock keys
        case 0x39: return AGILIS_KEY_CAPS_LOCK;       // kVK_CapsLock

        // Function keys (non-sequential kVK codes)
        case 0x7A: return AGILIS_KEY_F1;
        case 0x78: return AGILIS_KEY_F1 + 1;   // F2
        case 0x63: return AGILIS_KEY_F1 + 2;   // F3
        case 0x76: return AGILIS_KEY_F1 + 3;   // F4
        case 0x60: return AGILIS_KEY_F1 + 4;   // F5
        case 0x61: return AGILIS_KEY_F1 + 5;   // F6
        case 0x62: return AGILIS_KEY_F1 + 6;   // F7
        case 0x64: return AGILIS_KEY_F1 + 7;   // F8
        case 0x65: return AGILIS_KEY_F1 + 8;   // F9
        case 0x6D: return AGILIS_KEY_F1 + 9;   // F10
        case 0x67: return AGILIS_KEY_F1 + 10;  // F11
        case 0x6F: return AGILIS_KEY_F1 + 11;  // F12

        // Navigation
        case 0x72: return AGILIS_KEY_INSERT;     // kVK_Help (Mac Insert equivalent)
        case 0x73: return AGILIS_KEY_HOME;       // kVK_Home
        case 0x74: return AGILIS_KEY_PAGE_UP;    // kVK_PageUp
        case 0x75: return AGILIS_KEY_DELETE;     // kVK_ForwardDelete
        case 0x77: return AGILIS_KEY_END;        // kVK_End
        case 0x79: return AGILIS_KEY_PAGE_DOWN;  // kVK_PageDown
        case 0x7C: return AGILIS_KEY_RIGHT;      // kVK_RightArrow
        case 0x7B: return AGILIS_KEY_LEFT;       // kVK_LeftArrow
        case 0x7D: return AGILIS_KEY_DOWN;       // kVK_DownArrow
        case 0x7E: return AGILIS_KEY_UP;         // kVK_UpArrow

        // Modifiers
        case 0x3B: return AGILIS_KEY_LEFT_CONTROL;  // kVK_Control
        case 0x38: return AGILIS_KEY_LEFT_SHIFT;    // kVK_Shift
        case 0x3A: return AGILIS_KEY_LEFT_ALT;      // kVK_Option
        case 0x37: return AGILIS_KEY_LEFT_SUPER;    // kVK_Command (Left)
        case 0x3E: return AGILIS_KEY_RIGHT_CONTROL; // kVK_RightControl
        case 0x3C: return AGILIS_KEY_RIGHT_SHIFT;   // kVK_RightShift
        case 0x3D: return AGILIS_KEY_RIGHT_ALT;     // kVK_RightOption
        case 0x36: return AGILIS_KEY_RIGHT_SUPER;   // kVK_RightCommand

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

    bool keys[AGILIS_MAX_KEYS];
    bool keys_pressed[AGILIS_MAX_KEYS];           // sticky: set on DOWN, cleared per poll
    uint32_t char_pressed;

    bool mouse_buttons[AGILIS_MAX_MOUSE_BUTTONS];
    bool mouse_buttons_pressed[AGILIS_MAX_MOUSE_BUTTONS]; // sticky: set on DOWN, cleared per poll
    float mouse_x, mouse_y;
    float mouse_dx, mouse_dy;
    float mouse_scroll;
    float prev_mouse_x, prev_mouse_y;
    bool mouse_initialized;

    // Cursor state
    bool cursor_visible;
    bool mouse_captured;

    // Gamepad state (polled from GCController)
    bool gamepad_available[AGILIS_MAX_GAMEPADS];
    bool gamepad_buttons[AGILIS_MAX_GAMEPADS][MAX_GAMEPAD_BUTTONS];
    bool gamepad_buttons_pressed[AGILIS_MAX_GAMEPADS][MAX_GAMEPAD_BUTTONS];
    float gamepad_axes[AGILIS_MAX_GAMEPADS][MAX_GAMEPAD_AXES];
    char gamepad_names[AGILIS_MAX_GAMEPADS][128];

    int target_fps;
    bool vsync;
};

// Global window pointer for gamepad functions (which don't take PlatformWindow*)
static PlatformWindow* g_window = NULL;

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
        w->cursor_visible = true;

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

        g_window = w;
        return w;
    }
}

void platform_destroy_window(PlatformWindow* w) {
    if (!w) return;
    @autoreleasepool {
        if (g_window == w) g_window = NULL;
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
        // Compute mouse delta (in capture mode, deltas are accumulated from raw events)
        if (w->mouse_captured) {
            // Deltas will be accumulated from event handler below; reset here
            w->mouse_dx = 0;
            w->mouse_dy = 0;
        } else if (w->mouse_initialized) {
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

        memset(w->keys_pressed, 0, sizeof(w->keys_pressed));
        memset(w->mouse_buttons_pressed, 0, sizeof(w->mouse_buttons_pressed));

        NSEvent* event;
        while ((event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                           untilDate:[NSDate distantPast]
                                              inMode:NSDefaultRunLoopMode
                                             dequeue:YES])) {
            switch ([event type]) {
                case NSEventTypeKeyDown: {
                    int key = macos_keycode_to_agilis([event keyCode]);
                    if (key >= 0 && key < AGILIS_MAX_KEYS) {
                        w->keys[key] = true;
                        w->keys_pressed[key] = true;
                    }
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
                    if (key >= 0 && key < AGILIS_MAX_KEYS)
                        w->keys[key] = false;
                    break;
                }
                case NSEventTypeLeftMouseDown:  w->mouse_buttons[0] = true; w->mouse_buttons_pressed[0] = true; break;
                case NSEventTypeLeftMouseUp:    w->mouse_buttons[0] = false; break;
                case NSEventTypeRightMouseDown: w->mouse_buttons[1] = true; w->mouse_buttons_pressed[1] = true; break;
                case NSEventTypeRightMouseUp:   w->mouse_buttons[1] = false; break;
                case NSEventTypeOtherMouseDown: {
                    NSInteger btn = [event buttonNumber];
                    if (btn >= 2 && btn < AGILIS_MAX_MOUSE_BUTTONS) {
                        w->mouse_buttons[btn] = true;
                        w->mouse_buttons_pressed[btn] = true;
                    }
                    break;
                }
                case NSEventTypeOtherMouseUp: {
                    NSInteger btn = [event buttonNumber];
                    if (btn >= 2 && btn < AGILIS_MAX_MOUSE_BUTTONS) {
                        w->mouse_buttons[btn] = false;
                    }
                    break;
                }
                case NSEventTypeMouseMoved:
                case NSEventTypeLeftMouseDragged:
                case NSEventTypeRightMouseDragged:
                case NSEventTypeOtherMouseDragged: {
                    if (w->mouse_captured) {
                        // In capture mode, use raw deltas instead of position
                        w->mouse_dx += (float)[event deltaX];
                        w->mouse_dy += (float)[event deltaY];
                    } else {
                        NSPoint loc = [event locationInWindow];
                        NSRect frame = [w->ns_view frame];
                        w->mouse_x = (float)loc.x;
                        w->mouse_y = (float)(frame.size.height - loc.y); // Flip Y
                    }
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

        // ---- Poll GCController Gamepad State ----
        NSArray<GCController*>* controllers = [GCController controllers];
        for (int i = 0; i < AGILIS_MAX_GAMEPADS; i++) {
            bool was_available = w->gamepad_available[i];
            w->gamepad_available[i] = (i < (int)[controllers count]);

            if (!w->gamepad_available[i]) {
                if (was_available) {
                    // Controller disconnected — clear state
                    memset(w->gamepad_buttons[i], 0, sizeof(w->gamepad_buttons[i]));
                    memset(w->gamepad_axes[i], 0, sizeof(w->gamepad_axes[i]));
                    w->gamepad_names[i][0] = '\0';
                }
                memset(w->gamepad_buttons_pressed[i], 0, sizeof(w->gamepad_buttons_pressed[i]));
                continue;
            }

            GCController* controller = controllers[i];
            GCExtendedGamepad* gp = controller.extendedGamepad;
            if (!gp) {
                w->gamepad_available[i] = false;
                memset(w->gamepad_buttons_pressed[i], 0, sizeof(w->gamepad_buttons_pressed[i]));
                continue;
            }

            // Copy controller name
            if (!was_available) {
                const char* cname = controller.vendorName ? [controller.vendorName UTF8String] : "Controller";
                strncpy(w->gamepad_names[i], cname, 127);
                w->gamepad_names[i][127] = '\0';
            }

            // Map buttons: check current state, detect presses
            // Button mapping: GCExtendedGamepad → Agilis GamepadButton raw values
            struct { GCControllerButtonInput* btn; int idx; } button_map[] = {
                { gp.dpad.up,              1 },   // dpadUp
                { gp.dpad.right,           2 },   // dpadRight
                { gp.dpad.down,            3 },   // dpadDown
                { gp.dpad.left,            4 },   // dpadLeft
                { gp.buttonY,              5 },   // faceUp
                { gp.buttonB,              6 },   // faceRight
                { gp.buttonA,              7 },   // faceDown
                { gp.buttonX,              8 },   // faceLeft
                { gp.leftShoulder,         9 },   // leftBumper
                { gp.rightShoulder,       11 },   // rightBumper
                { gp.buttonMenu,          15 },   // start
                { gp.leftThumbstickButton,16 },   // leftStick
                { gp.rightThumbstickButton,17 },  // rightStick
            };
            int button_count = sizeof(button_map) / sizeof(button_map[0]);

            memset(w->gamepad_buttons_pressed[i], 0, sizeof(w->gamepad_buttons_pressed[i]));

            for (int b = 0; b < button_count; b++) {
                int idx = button_map[b].idx;
                bool cur = button_map[b].btn.pressed;
                bool prev = w->gamepad_buttons[i][idx];
                w->gamepad_buttons[i][idx] = cur;
                if (cur && !prev) w->gamepad_buttons_pressed[i][idx] = true;
            }

            // Triggers as digital buttons (threshold > 0.5)
            {
                bool lt_cur = gp.leftTrigger.value > 0.5f;
                bool lt_prev = w->gamepad_buttons[i][10];
                w->gamepad_buttons[i][10] = lt_cur;
                if (lt_cur && !lt_prev) w->gamepad_buttons_pressed[i][10] = true;

                bool rt_cur = gp.rightTrigger.value > 0.5f;
                bool rt_prev = w->gamepad_buttons[i][12];
                w->gamepad_buttons[i][12] = rt_cur;
                if (rt_cur && !rt_prev) w->gamepad_buttons_pressed[i][12] = true;
            }

            // Optional buttons (may be nil on some controllers)
            if (gp.buttonOptions) {
                bool cur = gp.buttonOptions.pressed;
                bool prev = w->gamepad_buttons[i][13];
                w->gamepad_buttons[i][13] = cur;
                if (cur && !prev) w->gamepad_buttons_pressed[i][13] = true;
            }
            if (gp.buttonHome) {
                bool cur = gp.buttonHome.pressed;
                bool prev = w->gamepad_buttons[i][14];
                w->gamepad_buttons[i][14] = cur;
                if (cur && !prev) w->gamepad_buttons_pressed[i][14] = true;
            }

            // Axes
            w->gamepad_axes[i][0] = gp.leftThumbstick.xAxis.value;       // leftX
            w->gamepad_axes[i][1] = -gp.leftThumbstick.yAxis.value;      // leftY (invert: GC Y-up → Agilis Y-down)
            w->gamepad_axes[i][2] = gp.rightThumbstick.xAxis.value;      // rightX
            w->gamepad_axes[i][3] = -gp.rightThumbstick.yAxis.value;     // rightY (invert)
            w->gamepad_axes[i][4] = gp.leftTrigger.value;                // leftTrigger
            w->gamepad_axes[i][5] = gp.rightTrigger.value;               // rightTrigger
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
    if (!w || key < 0 || key >= AGILIS_MAX_KEYS) return false;
    return w->keys[key];
}

bool platform_key_pressed(PlatformWindow* w, int key) {
    if (!w || key < 0 || key >= AGILIS_MAX_KEYS) return false;
    return w->keys_pressed[key];
}

uint32_t platform_char_pressed(PlatformWindow* w) {
    return w ? w->char_pressed : 0;
}

// ---- Mouse ----

bool platform_is_mouse_button_down(PlatformWindow* w, int button) {
    if (!w || button < 0 || button >= AGILIS_MAX_MOUSE_BUTTONS) return false;
    return w->mouse_buttons[button];
}

bool platform_mouse_button_pressed(PlatformWindow* w, int button) {
    if (!w || button < 0 || button >= AGILIS_MAX_MOUSE_BUTTONS) return false;
    return w->mouse_buttons_pressed[button];
}

float platform_mouse_x(PlatformWindow* w) { return w ? w->mouse_x : 0; }
float platform_mouse_y(PlatformWindow* w) { return w ? w->mouse_y : 0; }
float platform_mouse_dx(PlatformWindow* w) { return w ? w->mouse_dx : 0; }
float platform_mouse_dy(PlatformWindow* w) { return w ? w->mouse_dy : 0; }
float platform_mouse_scroll(PlatformWindow* w) { return w ? w->mouse_scroll : 0; }

// ---- Cursor & Mouse Capture ----

void platform_show_cursor(PlatformWindow* w, bool visible) {
    if (!w || w->cursor_visible == visible) return;
    w->cursor_visible = visible;
    if (visible) {
        [NSCursor unhide];
    } else {
        [NSCursor hide];
    }
}

bool platform_is_cursor_visible(PlatformWindow* w) {
    return w ? w->cursor_visible : true;
}

void platform_set_mouse_captured(PlatformWindow* w, bool captured) {
    if (!w || w->mouse_captured == captured) return;
    w->mouse_captured = captured;
    if (captured) {
        CGAssociateMouseAndMouseCursorPosition(false);
        if (w->cursor_visible) {
            [NSCursor hide];
        }
        w->mouse_dx = 0;
        w->mouse_dy = 0;
    } else {
        CGAssociateMouseAndMouseCursorPosition(true);
        if (w->cursor_visible) {
            [NSCursor unhide];
        }
        // Reinitialize position tracking after release
        NSPoint loc = [w->ns_window mouseLocationOutsideOfEventStream];
        NSRect frame = [w->ns_view frame];
        w->mouse_x = (float)loc.x;
        w->mouse_y = (float)(frame.size.height - loc.y);
        w->prev_mouse_x = w->mouse_x;
        w->prev_mouse_y = w->mouse_y;
    }
}

bool platform_is_mouse_captured(PlatformWindow* w) {
    return w ? w->mouse_captured : false;
}

// ---- Gamepad (GCController) ----

bool platform_is_gamepad_available(int index) {
    if (!g_window || index < 0 || index >= AGILIS_MAX_GAMEPADS) return false;
    return g_window->gamepad_available[index];
}

bool platform_is_gamepad_button_down(int index, int button) {
    if (!g_window || index < 0 || index >= AGILIS_MAX_GAMEPADS) return false;
    if (button < 0 || button >= MAX_GAMEPAD_BUTTONS) return false;
    return g_window->gamepad_buttons[index][button];
}

float platform_gamepad_axis(int index, int axis) {
    if (!g_window || index < 0 || index >= AGILIS_MAX_GAMEPADS) return 0;
    if (axis < 0 || axis >= MAX_GAMEPAD_AXES) return 0;
    return g_window->gamepad_axes[index][axis];
}

const char* platform_gamepad_name(int index) {
    if (!g_window || index < 0 || index >= AGILIS_MAX_GAMEPADS) return NULL;
    if (!g_window->gamepad_available[index]) return NULL;
    return g_window->gamepad_names[index];
}

bool platform_gamepad_button_pressed(int index, int button) {
    if (!g_window || index < 0 || index >= AGILIS_MAX_GAMEPADS) return false;
    if (button < 0 || button >= MAX_GAMEPAD_BUTTONS) return false;
    return g_window->gamepad_buttons_pressed[index][button];
}

void platform_gamepad_set_vibration(int index, float leftMotor, float rightMotor) {
    // GCController haptics require AudioToolbox/CHHapticEngine — no-op for now
    (void)index;
    (void)leftMotor;
    (void)rightMotor;
}

// ---- Frame Timing ----

void platform_set_target_fps(PlatformWindow* w, int fps) {
    if (w) w->target_fps = fps;
}

void platform_set_vsync(PlatformWindow* w, bool enabled) {
    if (w) w->vsync = enabled;
}

// ---- Touch (stubs — not applicable on macOS) ----

int platform_touch_count(PlatformWindow* w) {
    (void)w;
    return 0;
}

PlatformTouch platform_touch_at(PlatformWindow* w, int index) {
    (void)w;
    (void)index;
    PlatformTouch t = {0};
    return t;
}

#endif // !TARGET_OS_IOS && !TARGET_OS_TV && !TARGET_OS_WATCH
#endif // __APPLE__

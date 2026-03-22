#if defined(__APPLE__)
#include <TargetConditionals.h>
#if TARGET_OS_IOS

#include "platform.h"
#import <UIKit/UIKit.h>
#import <GameController/GameController.h>
#include <stdlib.h>
#include <string.h>

#define MAX_GAMEPAD_BUTTONS 18
#define MAX_GAMEPAD_AXES 6

// ---- Platform Window ----

struct PlatformWindow {
    UIWindow* ui_window;
    UIViewController* view_controller;
    UIView* gl_view;

    bool should_close;
    bool resized;
    int width;
    int height;

    // Keyboard (not used on iOS, but must exist for API conformance)
    bool keys[AGILIS_MAX_KEYS];
    bool keys_pressed[AGILIS_MAX_KEYS];
    uint32_t char_pressed;

    // Mouse (mapped from first touch for compatibility)
    bool mouse_buttons[AGILIS_MAX_MOUSE_BUTTONS];
    bool mouse_buttons_pressed[AGILIS_MAX_MOUSE_BUTTONS];
    float mouse_x, mouse_y;
    float mouse_dx, mouse_dy;
    float mouse_scroll;
    float prev_mouse_x, prev_mouse_y;
    bool mouse_initialized;
    bool cursor_visible;
    bool mouse_captured;

    // Touch
    PlatformTouch touches[AGILIS_MAX_TOUCHES];
    int touch_count;

    // Gamepad
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

// ---- AgilisGLView (touch-tracking UIView with CAEAGLLayer) ----

@interface AgilisGLView : UIView
@property (nonatomic, assign) PlatformWindow* platform;
@end

@implementation AgilisGLView

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (void)updateTouches:(NSSet<UITouch*>*)allTouches {
    if (!self.platform) return;

    PlatformWindow* w = self.platform;
    int count = 0;

    for (UITouch* touch in allTouches) {
        if (count >= AGILIS_MAX_TOUCHES) break;

        CGPoint loc = [touch locationInView:self];
        PlatformTouch* pt = &w->touches[count];
        pt->id = (int32_t)(uintptr_t)touch;  // Use pointer as unique ID
        pt->x = (float)loc.x;
        pt->y = (float)loc.y;

        switch (touch.phase) {
            case UITouchPhaseBegan:     pt->phase = AGILIS_TOUCH_BEGAN; break;
            case UITouchPhaseMoved:
            case UITouchPhaseStationary: pt->phase = AGILIS_TOUCH_MOVED; break;
            case UITouchPhaseEnded:     pt->phase = AGILIS_TOUCH_ENDED; break;
            case UITouchPhaseCancelled: pt->phase = AGILIS_TOUCH_CANCELLED; break;
            default:                    pt->phase = AGILIS_TOUCH_CANCELLED; break;
        }
        count++;
    }
    w->touch_count = count;

    // Map first touch to mouse for compatibility
    if (count > 0) {
        PlatformTouch* first = &w->touches[0];
        w->mouse_x = first->x;
        w->mouse_y = first->y;

        if (first->phase == AGILIS_TOUCH_BEGAN) {
            w->mouse_buttons[0] = true;
            w->mouse_buttons_pressed[0] = true;
        } else if (first->phase == AGILIS_TOUCH_ENDED || first->phase == AGILIS_TOUCH_CANCELLED) {
            w->mouse_buttons[0] = false;
        }
    }
}

- (void)touchesBegan:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    [self updateTouches:[event allTouches]];
}

- (void)touchesMoved:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    [self updateTouches:[event allTouches]];
}

- (void)touchesEnded:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    [self updateTouches:[event allTouches]];
}

- (void)touchesCancelled:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    [self updateTouches:[event allTouches]];
}

@end

// ---- AgilisViewController ----

@interface AgilisIOSViewController : UIViewController
@property (nonatomic, assign) PlatformWindow* platform;
@end

@implementation AgilisIOSViewController

- (void)loadView {
    AgilisGLView* glView = [[AgilisGLView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    glView.platform = self.platform;
    glView.multipleTouchEnabled = YES;
    glView.userInteractionEnabled = YES;
    glView.contentScaleFactor = [UIScreen mainScreen].scale;

    // Configure the CAEAGLLayer
    CAEAGLLayer* eaglLayer = (CAEAGLLayer*)glView.layer;
    eaglLayer.opaque = YES;
    eaglLayer.drawableProperties = @{
        kEAGLDrawablePropertyRetainedBacking: @NO,
        kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8
    };

    self.view = glView;
    self.platform->gl_view = glView;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

- (BOOL)shouldAutorotate {
    return YES;
}

@end

// ---- Window Lifecycle ----

PlatformWindow* platform_create_window(const PlatformWindowConfig* config) {
    @autoreleasepool {
        PlatformWindow* w = (PlatformWindow*)calloc(1, sizeof(PlatformWindow));
        if (!w) return NULL;

        CGRect screenBounds = [UIScreen mainScreen].bounds;
        w->width = (int)screenBounds.size.width;
        w->height = (int)screenBounds.size.height;
        w->target_fps = config->target_fps;
        w->vsync = config->vsync;
        w->cursor_visible = true;

        // Create the view controller (which creates the GL view in loadView)
        AgilisIOSViewController* vc = [[AgilisIOSViewController alloc] init];
        vc.platform = w;
        w->view_controller = vc;

        // Create the UIWindow
        UIWindow* window;
        if (@available(iOS 13.0, *)) {
            UIWindowScene* scene = nil;
            for (UIScene* s in [UIApplication sharedApplication].connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]]) {
                    scene = (UIWindowScene*)s;
                    break;
                }
            }
            if (scene) {
                window = [[UIWindow alloc] initWithWindowScene:scene];
            } else {
                window = [[UIWindow alloc] initWithFrame:screenBounds];
            }
        } else {
            window = [[UIWindow alloc] initWithFrame:screenBounds];
        }

        window.rootViewController = vc;
        [window makeKeyAndVisible];
        w->ui_window = window;

        // Force layout so the GL view's layer is ready
        [vc loadViewIfNeeded];

        // Update size from the actual view (accounts for safe area, scale)
        CGRect viewBounds = vc.view.bounds;
        w->width = (int)(viewBounds.size.width);
        w->height = (int)(viewBounds.size.height);

        g_window = w;
        return w;
    }
}

void platform_destroy_window(PlatformWindow* w) {
    if (!w) return;
    @autoreleasepool {
        if (g_window == w) g_window = NULL;
        w->ui_window.hidden = YES;
        w->ui_window = nil;
        w->view_controller = nil;
        w->gl_view = nil;
        free(w);
    }
}

bool platform_should_close(PlatformWindow* w) {
    // iOS apps don't "close" — the OS manages lifecycle
    return w ? w->should_close : true;
}

void platform_poll_events(PlatformWindow* w) {
    if (!w) return;
    @autoreleasepool {
        // Compute mouse delta from touch position changes
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
        memset(w->keys_pressed, 0, sizeof(w->keys_pressed));
        memset(w->mouse_buttons_pressed, 0, sizeof(w->mouse_buttons_pressed));

        // Clear ended/cancelled touches from the previous frame
        int live = 0;
        for (int i = 0; i < w->touch_count; i++) {
            if (w->touches[i].phase != AGILIS_TOUCH_ENDED &&
                w->touches[i].phase != AGILIS_TOUCH_CANCELLED) {
                // Promote began → moved for next frame
                if (w->touches[i].phase == AGILIS_TOUCH_BEGAN) {
                    w->touches[i].phase = AGILIS_TOUCH_MOVED;
                }
                w->touches[live++] = w->touches[i];
            }
        }
        w->touch_count = live;

        // Update window size (may change on rotation)
        if (w->gl_view) {
            CGRect bounds = w->gl_view.bounds;
            int newW = (int)bounds.size.width;
            int newH = (int)bounds.size.height;
            if (newW != w->width || newH != w->height) {
                w->width = newW;
                w->height = newH;
                w->resized = true;
            }
        }

        // ---- Poll GCController Gamepad State ----
        NSArray<GCController*>* controllers = [GCController controllers];
        for (int i = 0; i < AGILIS_MAX_GAMEPADS; i++) {
            bool was_available = w->gamepad_available[i];
            w->gamepad_available[i] = (i < (int)[controllers count]);

            if (!w->gamepad_available[i]) {
                if (was_available) {
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

            if (!was_available) {
                const char* cname = controller.vendorName ? [controller.vendorName UTF8String] : "Controller";
                strncpy(w->gamepad_names[i], cname, 127);
                w->gamepad_names[i][127] = '\0';
            }

            struct { GCControllerButtonInput* btn; int idx; } button_map[] = {
                { gp.dpad.up,              1 },
                { gp.dpad.right,           2 },
                { gp.dpad.down,            3 },
                { gp.dpad.left,            4 },
                { gp.buttonY,              5 },
                { gp.buttonB,              6 },
                { gp.buttonA,              7 },
                { gp.buttonX,              8 },
                { gp.leftShoulder,         9 },
                { gp.rightShoulder,       11 },
                { gp.buttonMenu,          15 },
                { gp.leftThumbstickButton,16 },
                { gp.rightThumbstickButton,17 },
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
            w->gamepad_axes[i][0] = gp.leftThumbstick.xAxis.value;
            w->gamepad_axes[i][1] = -gp.leftThumbstick.yAxis.value;
            w->gamepad_axes[i][2] = gp.rightThumbstick.xAxis.value;
            w->gamepad_axes[i][3] = -gp.rightThumbstick.yAxis.value;
            w->gamepad_axes[i][4] = gp.leftTrigger.value;
            w->gamepad_axes[i][5] = gp.rightTrigger.value;
        }
    }
}

int platform_window_width(PlatformWindow* w) { return w ? w->width : 0; }
int platform_window_height(PlatformWindow* w) { return w ? w->height : 0; }
bool platform_window_resized(PlatformWindow* w) { return w ? w->resized : false; }

// ---- EGL Surface Hooks ----

void* platform_native_display(PlatformWindow* w) {
    (void)w;
    return NULL;  // EGL_DEFAULT_DISPLAY — ANGLE uses Metal backend
}

void* platform_native_window(PlatformWindow* w) {
    if (!w || !w->gl_view) return NULL;
    return (__bridge void*)[w->gl_view layer];
}

// ---- Keyboard (stubs — no physical keyboard on iOS) ----

bool platform_is_key_down(PlatformWindow* w, int key) {
    (void)w; (void)key;
    return false;
}

bool platform_key_pressed(PlatformWindow* w, int key) {
    (void)w; (void)key;
    return false;
}

uint32_t platform_char_pressed(PlatformWindow* w) {
    (void)w;
    return 0;
}

// ---- Mouse (mapped from first touch) ----

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

// ---- Cursor (no-ops on iOS) ----

void platform_show_cursor(PlatformWindow* w, bool visible) {
    (void)w; (void)visible;
}

bool platform_is_cursor_visible(PlatformWindow* w) {
    (void)w;
    return true;
}

void platform_set_mouse_captured(PlatformWindow* w, bool captured) {
    (void)w; (void)captured;
}

bool platform_is_mouse_captured(PlatformWindow* w) {
    (void)w;
    return false;
}

// ---- Touch ----

int platform_touch_count(PlatformWindow* w) {
    return w ? w->touch_count : 0;
}

PlatformTouch platform_touch_at(PlatformWindow* w, int index) {
    if (!w || index < 0 || index >= w->touch_count) {
        PlatformTouch t = {0};
        return t;
    }
    return w->touches[index];
}

// ---- Gamepad (GCController — same API as macOS) ----

bool platform_is_gamepad_available(int index) {
    if (!g_window || index < 0 || index >= AGILIS_MAX_GAMEPADS) return false;
    return g_window->gamepad_available[index];
}

bool platform_is_gamepad_button_down(int index, int button) {
    if (!g_window || index < 0 || index >= AGILIS_MAX_GAMEPADS) return false;
    if (button < 0 || button >= MAX_GAMEPAD_BUTTONS) return false;
    return g_window->gamepad_buttons[index][button];
}

bool platform_gamepad_button_pressed(int index, int button) {
    if (!g_window || index < 0 || index >= AGILIS_MAX_GAMEPADS) return false;
    if (button < 0 || button >= MAX_GAMEPAD_BUTTONS) return false;
    return g_window->gamepad_buttons_pressed[index][button];
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

void platform_gamepad_set_vibration(int index, float leftMotor, float rightMotor) {
    (void)index; (void)leftMotor; (void)rightMotor;
}

// ---- Frame Timing ----

void platform_set_target_fps(PlatformWindow* w, int fps) {
    if (w) w->target_fps = fps;
}

void platform_set_vsync(PlatformWindow* w, bool enabled) {
    if (w) w->vsync = enabled;
}

#endif // TARGET_OS_IOS
#endif // __APPLE__

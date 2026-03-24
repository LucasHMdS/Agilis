#ifdef _WIN32

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <xinput.h>
#include "platform.h"
#include <stdlib.h>
#include <string.h>

// Key constants and limits are defined in platform.h (AGILIS_KEY_*, AGILIS_MAX_*)

// Global window pointer for gamepad functions (which don't take PlatformWindow*)
static PlatformWindow* g_window = NULL;

// ---- Platform Window ----

struct PlatformWindow {
    HWND hwnd;
    HDC hdc;
    bool should_close;
    bool resized;
    int width;
    int height;

    // Keyboard
    bool keys[AGILIS_MAX_KEYS];
    bool keys_pressed[AGILIS_MAX_KEYS];           // sticky: set on DOWN, cleared per poll
    uint32_t char_pressed;

    // Mouse
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

    // Gamepad state (tracked for pressed detection)
    bool gamepad_buttons[AGILIS_MAX_GAMEPADS][18];
    bool gamepad_buttons_pressed[AGILIS_MAX_GAMEPADS][18];

    // Config
    int target_fps;
    bool vsync;
};

// ---- VK -> USB HID Key Mapping ----

static int vk_to_agilis_key(WPARAM vk) {
    // Letters A-Z: VK_A(0x41) → USB HID 4..29
    if (vk >= 'A' && vk <= 'Z') return AGILIS_KEY_A + (int)(vk - 'A');
    // Digits 1-9: VK_1(0x31)..VK_9(0x39) → USB HID 30..38
    if (vk >= '1' && vk <= '9') return AGILIS_KEY_1 + (int)(vk - '1');
    // Digit 0: VK_0(0x30) → USB HID 39
    if (vk == '0') return AGILIS_KEY_0;

    switch (vk) {
        // Special keys
        case VK_RETURN:     return AGILIS_KEY_ENTER;
        case VK_ESCAPE:     return AGILIS_KEY_ESCAPE;
        case VK_BACK:       return AGILIS_KEY_BACKSPACE;
        case VK_TAB:        return AGILIS_KEY_TAB;
        case VK_SPACE:      return AGILIS_KEY_SPACE;

        // Punctuation (OEM keys)
        case VK_OEM_MINUS:  return AGILIS_KEY_MINUS;
        case VK_OEM_PLUS:   return AGILIS_KEY_EQUAL;      // = key (VK_OEM_PLUS is the =/+ key)
        case VK_OEM_4:      return AGILIS_KEY_LEFT_BRACKET;
        case VK_OEM_6:      return AGILIS_KEY_RIGHT_BRACKET;
        case VK_OEM_5:      return AGILIS_KEY_BACKSLASH;
        case VK_OEM_1:      return AGILIS_KEY_SEMICOLON;
        case VK_OEM_7:      return AGILIS_KEY_APOSTROPHE;
        case VK_OEM_3:      return AGILIS_KEY_GRAVE;
        case VK_OEM_COMMA:  return AGILIS_KEY_COMMA;
        case VK_OEM_PERIOD: return AGILIS_KEY_PERIOD;
        case VK_OEM_2:      return AGILIS_KEY_SLASH;

        // Lock keys
        case VK_CAPITAL:    return AGILIS_KEY_CAPS_LOCK;
        case VK_SCROLL:     return AGILIS_KEY_SCROLL_LOCK;
        case VK_NUMLOCK:    return AGILIS_KEY_NUM_LOCK;

        // Function keys
        case VK_F1:         return AGILIS_KEY_F1;
        case VK_F2:         return AGILIS_KEY_F1 + 1;
        case VK_F3:         return AGILIS_KEY_F1 + 2;
        case VK_F4:         return AGILIS_KEY_F1 + 3;
        case VK_F5:         return AGILIS_KEY_F1 + 4;
        case VK_F6:         return AGILIS_KEY_F1 + 5;
        case VK_F7:         return AGILIS_KEY_F1 + 6;
        case VK_F8:         return AGILIS_KEY_F1 + 7;
        case VK_F9:         return AGILIS_KEY_F1 + 8;
        case VK_F10:        return AGILIS_KEY_F1 + 9;
        case VK_F11:        return AGILIS_KEY_F1 + 10;
        case VK_F12:        return AGILIS_KEY_F1 + 11;

        // System keys
        case VK_SNAPSHOT:   return AGILIS_KEY_PRINT_SCREEN;
        case VK_PAUSE:      return AGILIS_KEY_PAUSE;

        // Navigation
        case VK_INSERT:     return AGILIS_KEY_INSERT;
        case VK_HOME:       return AGILIS_KEY_HOME;
        case VK_PRIOR:      return AGILIS_KEY_PAGE_UP;
        case VK_DELETE:     return AGILIS_KEY_DELETE;
        case VK_END:        return AGILIS_KEY_END;
        case VK_NEXT:       return AGILIS_KEY_PAGE_DOWN;
        case VK_RIGHT:      return AGILIS_KEY_RIGHT;
        case VK_LEFT:       return AGILIS_KEY_LEFT;
        case VK_DOWN:       return AGILIS_KEY_DOWN;
        case VK_UP:         return AGILIS_KEY_UP;

        // Application key
        case VK_APPS:       return AGILIS_KEY_MENU;

        // Modifiers
        case VK_LCONTROL:   return AGILIS_KEY_LEFT_CONTROL;
        case VK_LSHIFT:     return AGILIS_KEY_LEFT_SHIFT;
        case VK_LMENU:      return AGILIS_KEY_LEFT_ALT;
        case VK_LWIN:       return AGILIS_KEY_LEFT_SUPER;
        case VK_RCONTROL:   return AGILIS_KEY_RIGHT_CONTROL;
        case VK_RSHIFT:     return AGILIS_KEY_RIGHT_SHIFT;
        case VK_RMENU:      return AGILIS_KEY_RIGHT_ALT;
        case VK_RWIN:       return AGILIS_KEY_RIGHT_SUPER;

        default:            return -1;
    }
}

// ---- Window Procedure ----

static LRESULT CALLBACK window_proc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    PlatformWindow* w = (PlatformWindow*)GetWindowLongPtrW(hwnd, GWLP_USERDATA);
    if (!w) return DefWindowProcW(hwnd, msg, wParam, lParam);

    switch (msg) {
        case WM_CLOSE:
            w->should_close = true;
            return 0;

        case WM_SIZE:
            w->width = LOWORD(lParam);
            w->height = HIWORD(lParam);
            w->resized = true;
            return 0;

        case WM_KEYDOWN:
        case WM_SYSKEYDOWN: {
            int key = vk_to_agilis_key(wParam);
            if (key >= 0 && key < AGILIS_MAX_KEYS) {
                w->keys[key] = true;
                w->keys_pressed[key] = true;
            }
            return 0;
        }

        case WM_KEYUP:
        case WM_SYSKEYUP: {
            int key = vk_to_agilis_key(wParam);
            if (key >= 0 && key < AGILIS_MAX_KEYS)
                w->keys[key] = false;
            return 0;
        }

        case WM_CHAR:
            if (wParam >= 32)
                w->char_pressed = (uint32_t)wParam;
            return 0;

        case WM_LBUTTONDOWN: w->mouse_buttons[0] = true; w->mouse_buttons_pressed[0] = true; return 0;
        case WM_LBUTTONUP:   w->mouse_buttons[0] = false; return 0;
        case WM_RBUTTONDOWN: w->mouse_buttons[1] = true; w->mouse_buttons_pressed[1] = true; return 0;
        case WM_RBUTTONUP:   w->mouse_buttons[1] = false; return 0;
        case WM_MBUTTONDOWN: w->mouse_buttons[2] = true; w->mouse_buttons_pressed[2] = true; return 0;
        case WM_MBUTTONUP:   w->mouse_buttons[2] = false; return 0;

        case WM_XBUTTONDOWN: {
            WORD xbutton = HIWORD(wParam);
            if (xbutton == XBUTTON1) { w->mouse_buttons[3] = true; w->mouse_buttons_pressed[3] = true; }
            else if (xbutton == XBUTTON2) { w->mouse_buttons[4] = true; w->mouse_buttons_pressed[4] = true; }
            return TRUE;
        }
        case WM_XBUTTONUP: {
            WORD xbutton = HIWORD(wParam);
            if (xbutton == XBUTTON1) w->mouse_buttons[3] = false;
            else if (xbutton == XBUTTON2) w->mouse_buttons[4] = false;
            return TRUE;
        }

        case WM_MOUSEMOVE:
            w->mouse_x = (float)LOWORD(lParam);
            w->mouse_y = (float)HIWORD(lParam);
            return 0;

        case WM_MOUSEWHEEL:
            w->mouse_scroll = (float)GET_WHEEL_DELTA_WPARAM(wParam) / (float)WHEEL_DELTA;
            return 0;

        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;
    }

    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

// ---- Window Lifecycle ----

static const wchar_t* WINDOW_CLASS_NAME = L"AgilisWindow";
static bool class_registered = false;

PlatformWindow* platform_create_window(const PlatformWindowConfig* config) {
    PlatformWindow* w = (PlatformWindow*)calloc(1, sizeof(PlatformWindow));
    if (!w) return NULL;

    HINSTANCE hInstance = GetModuleHandleW(NULL);

    if (!class_registered) {
        WNDCLASSEXW wc = {0};
        wc.cbSize = sizeof(WNDCLASSEXW);
        wc.style = CS_HREDRAW | CS_VREDRAW | CS_OWNDC;
        wc.lpfnWndProc = window_proc;
        wc.hInstance = hInstance;
        wc.hCursor = LoadCursor(NULL, IDC_ARROW);
        wc.lpszClassName = WINDOW_CLASS_NAME;
        RegisterClassExW(&wc);
        class_registered = true;
    }

    DWORD style = WS_OVERLAPPEDWINDOW;
    if (!config->resizable)
        style &= ~(WS_THICKFRAME | WS_MAXIMIZEBOX);

    // Adjust rect to account for window chrome
    RECT rect = { 0, 0, config->width, config->height };
    AdjustWindowRect(&rect, style, FALSE);

    // Convert title to wide string
    int title_len = MultiByteToWideChar(CP_UTF8, 0, config->title, -1, NULL, 0);
    wchar_t* wide_title = (wchar_t*)malloc(title_len * sizeof(wchar_t));
    MultiByteToWideChar(CP_UTF8, 0, config->title, -1, wide_title, title_len);

    w->hwnd = CreateWindowExW(
        0, WINDOW_CLASS_NAME, wide_title, style,
        CW_USEDEFAULT, CW_USEDEFAULT,
        rect.right - rect.left, rect.bottom - rect.top,
        NULL, NULL, hInstance, NULL
    );
    free(wide_title);

    if (!w->hwnd) {
        free(w);
        return NULL;
    }

    SetWindowLongPtrW(w->hwnd, GWLP_USERDATA, (LONG_PTR)w);

    w->hdc = GetDC(w->hwnd);
    w->width = config->width;
    w->height = config->height;
    w->target_fps = config->target_fps;
    w->vsync = config->vsync;
    w->cursor_visible = true;

    ShowWindow(w->hwnd, SW_SHOW);
    UpdateWindow(w->hwnd);

    g_window = w;
    return w;
}

void platform_destroy_window(PlatformWindow* w) {
    if (!w) return;
    if (g_window == w) g_window = NULL;
    if (w->hdc) ReleaseDC(w->hwnd, w->hdc);
    if (w->hwnd) DestroyWindow(w->hwnd);
    free(w);
}

bool platform_should_close(PlatformWindow* w) {
    return w ? w->should_close : true;
}

void platform_poll_events(PlatformWindow* w) {
    if (!w) return;

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

    // Reset per-frame state
    w->mouse_scroll = 0;
    w->char_pressed = 0;
    w->resized = false;
    memset(w->keys_pressed, 0, sizeof(w->keys_pressed));
    memset(w->mouse_buttons_pressed, 0, sizeof(w->mouse_buttons_pressed));

    // Process all pending messages
    MSG msg;
    while (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE)) {
        if (msg.message == WM_QUIT) {
            w->should_close = true;
            break;
        }
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    // Re-center cursor when captured (after processing messages so delta is computed)
    if (w->mouse_captured) {
        RECT rect;
        GetClientRect(w->hwnd, &rect);
        POINT topLeft = { rect.left, rect.top };
        POINT bottomRight = { rect.right, rect.bottom };
        ClientToScreen(w->hwnd, &topLeft);
        ClientToScreen(w->hwnd, &bottomRight);
        int cx = (topLeft.x + bottomRight.x) / 2;
        int cy = (topLeft.y + bottomRight.y) / 2;
        SetCursorPos(cx, cy);
        POINT client = { cx, cy };
        ScreenToClient(w->hwnd, &client);
        w->prev_mouse_x = (float)client.x;
        w->prev_mouse_y = (float)client.y;
        w->mouse_x = w->prev_mouse_x;
        w->mouse_y = w->prev_mouse_y;
    }

    // ---- Poll XInput Gamepad State (for pressed detection) ----
    for (int i = 0; i < AGILIS_MAX_GAMEPADS; i++) {
        memset(w->gamepad_buttons_pressed[i], 0, sizeof(w->gamepad_buttons_pressed[i]));
        XINPUT_STATE state;
        if (XInputGetState((DWORD)i, &state) != ERROR_SUCCESS) {
            memset(w->gamepad_buttons[i], 0, sizeof(w->gamepad_buttons[i]));
            continue;
        }
        // Map all buttons and detect transitions
        struct { WORD mask; int idx; } btn_map[] = {
            { XINPUT_GAMEPAD_DPAD_UP,         1 },
            { XINPUT_GAMEPAD_DPAD_RIGHT,      2 },
            { XINPUT_GAMEPAD_DPAD_DOWN,       3 },
            { XINPUT_GAMEPAD_DPAD_LEFT,       4 },
            { XINPUT_GAMEPAD_Y,               5 },
            { XINPUT_GAMEPAD_B,               6 },
            { XINPUT_GAMEPAD_A,               7 },
            { XINPUT_GAMEPAD_X,               8 },
            { XINPUT_GAMEPAD_LEFT_SHOULDER,    9 },
            { XINPUT_GAMEPAD_RIGHT_SHOULDER,  11 },
            { XINPUT_GAMEPAD_BACK,            13 },
            { 0x0400,                         14 },  // Guide
            { XINPUT_GAMEPAD_START,           15 },
            { XINPUT_GAMEPAD_LEFT_THUMB,      16 },
            { XINPUT_GAMEPAD_RIGHT_THUMB,     17 },
        };
        int btn_count = sizeof(btn_map) / sizeof(btn_map[0]);
        for (int b = 0; b < btn_count; b++) {
            int idx = btn_map[b].idx;
            bool cur = (state.Gamepad.wButtons & btn_map[b].mask) != 0;
            bool prev = w->gamepad_buttons[i][idx];
            w->gamepad_buttons[i][idx] = cur;
            if (cur && !prev) w->gamepad_buttons_pressed[i][idx] = true;
        }
        // Triggers as digital buttons
        {
            bool lt = state.Gamepad.bLeftTrigger > 128;
            if (lt && !w->gamepad_buttons[i][10]) w->gamepad_buttons_pressed[i][10] = true;
            w->gamepad_buttons[i][10] = lt;
            bool rt = state.Gamepad.bRightTrigger > 128;
            if (rt && !w->gamepad_buttons[i][12]) w->gamepad_buttons_pressed[i][12] = true;
            w->gamepad_buttons[i][12] = rt;
        }
    }
}

int platform_window_width(PlatformWindow* w) {
    return w ? w->width : 0;
}

int platform_window_height(PlatformWindow* w) {
    return w ? w->height : 0;
}

bool platform_window_resized(PlatformWindow* w) {
    return w ? w->resized : false;
}

// ---- EGL Surface Hooks ----

void* platform_native_display(PlatformWindow* w) {
    return w ? (void*)w->hdc : NULL;
}

void* platform_native_window(PlatformWindow* w) {
    return w ? (void*)w->hwnd : NULL;
}

// ---- Keyboard ----

bool platform_is_key_down(PlatformWindow* w, int key) {
    if (!w || key < 0 || key >= AGILIS_MAX_KEYS) return false;
    return w->keys[key];
}

uint32_t platform_char_pressed(PlatformWindow* w) {
    return w ? w->char_pressed : 0;
}

bool platform_key_pressed(PlatformWindow* w, int key) {
    if (!w || key < 0 || key >= AGILIS_MAX_KEYS) return false;
    return w->keys_pressed[key];
}

bool platform_mouse_button_pressed(PlatformWindow* w, int button) {
    if (!w || button < 0 || button >= AGILIS_MAX_MOUSE_BUTTONS) return false;
    return w->mouse_buttons_pressed[button];
}

// ---- Mouse ----

bool platform_is_mouse_button_down(PlatformWindow* w, int button) {
    if (!w || button < 0 || button >= AGILIS_MAX_MOUSE_BUTTONS) return false;
    return w->mouse_buttons[button];
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
    ShowCursor(visible ? TRUE : FALSE);
}

bool platform_is_cursor_visible(PlatformWindow* w) {
    return w ? w->cursor_visible : true;
}

void platform_set_mouse_captured(PlatformWindow* w, bool captured) {
    if (!w || w->mouse_captured == captured) return;
    w->mouse_captured = captured;
    if (captured) {
        // Hide cursor and clip to window
        if (w->cursor_visible) {
            ShowCursor(FALSE);
        }
        RECT rect;
        GetClientRect(w->hwnd, &rect);
        POINT topLeft = { rect.left, rect.top };
        POINT bottomRight = { rect.right, rect.bottom };
        ClientToScreen(w->hwnd, &topLeft);
        ClientToScreen(w->hwnd, &bottomRight);
        RECT clipRect = { topLeft.x, topLeft.y, bottomRight.x, bottomRight.y };
        ClipCursor(&clipRect);
        // Center cursor
        int cx = (topLeft.x + bottomRight.x) / 2;
        int cy = (topLeft.y + bottomRight.y) / 2;
        SetCursorPos(cx, cy);
        // Reset deltas so centering doesn't generate a large delta
        POINT client = { cx, cy };
        ScreenToClient(w->hwnd, &client);
        w->mouse_x = (float)client.x;
        w->mouse_y = (float)client.y;
        w->prev_mouse_x = w->mouse_x;
        w->prev_mouse_y = w->mouse_y;
        w->mouse_dx = 0;
        w->mouse_dy = 0;
    } else {
        // Release cursor
        ClipCursor(NULL);
        if (w->cursor_visible) {
            ShowCursor(TRUE);
        }
    }
}

bool platform_is_mouse_captured(PlatformWindow* w) {
    return w ? w->mouse_captured : false;
}

// ---- Gamepad (XInput) ----

bool platform_is_gamepad_available(int index) {
    if (index < 0 || index >= AGILIS_MAX_GAMEPADS) return false;
    XINPUT_STATE state;
    return XInputGetState((DWORD)index, &state) == ERROR_SUCCESS;
}

// Agilis GamepadButton raw values → XInput mapping
static WORD agilis_button_to_xinput(int button) {
    switch (button) {
        case 1: return XINPUT_GAMEPAD_DPAD_UP;
        case 2: return XINPUT_GAMEPAD_DPAD_RIGHT;
        case 3: return XINPUT_GAMEPAD_DPAD_DOWN;
        case 4: return XINPUT_GAMEPAD_DPAD_LEFT;
        case 5: return XINPUT_GAMEPAD_Y;           // faceUp
        case 6: return XINPUT_GAMEPAD_B;           // faceRight
        case 7: return XINPUT_GAMEPAD_A;           // faceDown
        case 8: return XINPUT_GAMEPAD_X;           // faceLeft
        case 9: return XINPUT_GAMEPAD_LEFT_SHOULDER;
        case 10: return 0; // leftTrigger (analog, handled as axis)
        case 11: return XINPUT_GAMEPAD_RIGHT_SHOULDER;
        case 12: return 0; // rightTrigger (analog)
        case 13: return XINPUT_GAMEPAD_BACK;       // select
        case 14: return 0x0400;                    // guide (not standard XInput)
        case 15: return XINPUT_GAMEPAD_START;
        case 16: return XINPUT_GAMEPAD_LEFT_THUMB;
        case 17: return XINPUT_GAMEPAD_RIGHT_THUMB;
        default: return 0;
    }
}

bool platform_is_gamepad_button_down(int index, int button) {
    if (index < 0 || index >= AGILIS_MAX_GAMEPADS) return false;
    XINPUT_STATE state;
    if (XInputGetState((DWORD)index, &state) != ERROR_SUCCESS) return false;

    // Handle trigger buttons as digital press (threshold 128)
    if (button == 10) return state.Gamepad.bLeftTrigger > 128;
    if (button == 12) return state.Gamepad.bRightTrigger > 128;

    WORD mask = agilis_button_to_xinput(button);
    return (state.Gamepad.wButtons & mask) != 0;
}

float platform_gamepad_axis(int index, int axis) {
    if (index < 0 || index >= AGILIS_MAX_GAMEPADS) return 0;
    XINPUT_STATE state;
    if (XInputGetState((DWORD)index, &state) != ERROR_SUCCESS) return 0;

    switch (axis) {
        case 0: return (float)state.Gamepad.sThumbLX / 32767.0f; // leftX
        case 1: return (float)state.Gamepad.sThumbLY / -32767.0f; // leftY (inverted)
        case 2: return (float)state.Gamepad.sThumbRX / 32767.0f; // rightX
        case 3: return (float)state.Gamepad.sThumbRY / -32767.0f; // rightY (inverted)
        case 4: return (float)state.Gamepad.bLeftTrigger / 255.0f;  // leftTrigger 0-1
        case 5: return (float)state.Gamepad.bRightTrigger / 255.0f; // rightTrigger 0-1
        default: return 0;
    }
}

const char* platform_gamepad_name(int index) {
    if (index < 0 || index >= AGILIS_MAX_GAMEPADS) return NULL;
    XINPUT_STATE state;
    if (XInputGetState((DWORD)index, &state) != ERROR_SUCCESS) return NULL;
    return "Xbox Controller";
}

bool platform_gamepad_button_pressed(int index, int button) {
    if (!g_window || index < 0 || index >= AGILIS_MAX_GAMEPADS) return false;
    if (button < 0 || button >= 18) return false;
    return g_window->gamepad_buttons_pressed[index][button];
}

void platform_gamepad_set_vibration(int index, float leftMotor, float rightMotor) {
    if (index < 0 || index >= AGILIS_MAX_GAMEPADS) return;
    XINPUT_VIBRATION vibration;
    vibration.wLeftMotorSpeed = (WORD)(leftMotor * 65535.0f);
    vibration.wRightMotorSpeed = (WORD)(rightMotor * 65535.0f);
    XInputSetState((DWORD)index, &vibration);
}

// ---- Frame Timing ----

void platform_set_target_fps(PlatformWindow* w, int fps) {
    if (w) w->target_fps = fps;
}

void platform_set_vsync(PlatformWindow* w, bool enabled) {
    if (w) w->vsync = enabled;
    // VSync is controlled via EGL, not here
}

// ---- Touch (stubs — not applicable on Windows) ----

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

#endif // _WIN32

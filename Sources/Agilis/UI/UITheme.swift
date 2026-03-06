

/// Visual theme for all UI elements.
public struct UITheme: @unchecked Sendable {
    // Font
    public var font: FontHandle

    // Text
    public var textColor: Color
    public var titleFontSize: Float
    public var bodyFontSize: Float

    // Button
    public var buttonColor: Color
    public var buttonHoverColor: Color
    public var buttonPressColor: Color
    public var buttonFocusColor: Color
    public var buttonTextColor: Color

    // Panel
    public var panelColor: Color
    public var borderColor: Color

    // Slider
    public var sliderTrackColor: Color
    public var sliderFillColor: Color
    public var sliderKnobColor: Color

    // Toggle
    public var toggleOnColor: Color
    public var toggleOffColor: Color

    // Focus
    public var focusColor: Color

    // Dropdown
    public var dropdownColor: Color
    public var dropdownHoverColor: Color
    public var dropdownOptionColor: Color
    public var dropdownHighlightColor: Color

    // List
    public var listSelectionColor: Color

    // Modal
    public var modalOverlayColor: Color
    public var modalTitleColor: Color
    public var modalTitleBarColor: Color

    // Spacing
    public var defaultPadding: Float
    public var defaultSpacing: Float

    public init(
        font: FontHandle,
        textColor: Color = .white,
        titleFontSize: Float = 32,
        bodyFontSize: Float = 20,
        buttonColor: Color = Color(r: 60, g: 60, b: 60),
        buttonHoverColor: Color = Color(r: 80, g: 80, b: 80),
        buttonPressColor: Color = Color(r: 40, g: 40, b: 40),
        buttonFocusColor: Color = Color(r: 70, g: 70, b: 70),
        buttonTextColor: Color = .white,
        panelColor: Color = Color(r: 30, g: 30, b: 30, a: 200),
        borderColor: Color = Color(r: 100, g: 100, b: 100),
        sliderTrackColor: Color = Color(r: 50, g: 50, b: 50),
        sliderFillColor: Color = Color(r: 0, g: 150, b: 255),
        sliderKnobColor: Color = .white,
        toggleOnColor: Color = Color(r: 0, g: 180, b: 80),
        toggleOffColor: Color = Color(r: 80, g: 80, b: 80),
        focusColor: Color = Color(r: 0, g: 150, b: 255),
        dropdownColor: Color = Color(r: 60, g: 60, b: 60),
        dropdownHoverColor: Color = Color(r: 80, g: 80, b: 80),
        dropdownOptionColor: Color = Color(r: 45, g: 45, b: 45),
        dropdownHighlightColor: Color = Color(r: 0, g: 120, b: 215),
        listSelectionColor: Color = Color(r: 0, g: 120, b: 215, a: 160),
        modalOverlayColor: Color = Color(r: 0, g: 0, b: 0, a: 150),
        modalTitleColor: Color = .white,
        modalTitleBarColor: Color = Color(r: 50, g: 50, b: 50),
        defaultPadding: Float = 8,
        defaultSpacing: Float = 8
    ) {
        self.font = font
        self.textColor = textColor
        self.titleFontSize = titleFontSize
        self.bodyFontSize = bodyFontSize
        self.buttonColor = buttonColor
        self.buttonHoverColor = buttonHoverColor
        self.buttonPressColor = buttonPressColor
        self.buttonFocusColor = buttonFocusColor
        self.buttonTextColor = buttonTextColor
        self.panelColor = panelColor
        self.borderColor = borderColor
        self.sliderTrackColor = sliderTrackColor
        self.sliderFillColor = sliderFillColor
        self.sliderKnobColor = sliderKnobColor
        self.toggleOnColor = toggleOnColor
        self.toggleOffColor = toggleOffColor
        self.focusColor = focusColor
        self.dropdownColor = dropdownColor
        self.dropdownHoverColor = dropdownHoverColor
        self.dropdownOptionColor = dropdownOptionColor
        self.dropdownHighlightColor = dropdownHighlightColor
        self.listSelectionColor = listSelectionColor
        self.modalOverlayColor = modalOverlayColor
        self.modalTitleColor = modalTitleColor
        self.modalTitleBarColor = modalTitleBarColor
        self.defaultPadding = defaultPadding
        self.defaultSpacing = defaultSpacing
    }

    /// A dark theme suitable for most games.
    public static func dark(font: FontHandle) -> UITheme {
        UITheme(font: font)
    }

    /// A light theme.
    public static func light(font: FontHandle) -> UITheme {
        UITheme(
            font: font,
            textColor: Color(r: 20, g: 20, b: 20),
            buttonColor: Color(r: 200, g: 200, b: 200),
            buttonHoverColor: Color(r: 180, g: 180, b: 180),
            buttonPressColor: Color(r: 160, g: 160, b: 160),
            buttonFocusColor: Color(r: 190, g: 190, b: 190),
            buttonTextColor: Color(r: 20, g: 20, b: 20),
            panelColor: Color(r: 240, g: 240, b: 240, a: 230),
            borderColor: Color(r: 180, g: 180, b: 180),
            sliderTrackColor: Color(r: 200, g: 200, b: 200),
            sliderFillColor: Color(r: 0, g: 120, b: 215),
            sliderKnobColor: Color(r: 40, g: 40, b: 40),
            toggleOnColor: Color(r: 0, g: 150, b: 60),
            toggleOffColor: Color(r: 180, g: 180, b: 180),
            focusColor: Color(r: 0, g: 120, b: 215),
            dropdownColor: Color(r: 210, g: 210, b: 210),
            dropdownHoverColor: Color(r: 190, g: 190, b: 190),
            dropdownOptionColor: Color(r: 245, g: 245, b: 245),
            dropdownHighlightColor: Color(r: 0, g: 120, b: 215),
            listSelectionColor: Color(r: 0, g: 120, b: 215, a: 140),
            modalOverlayColor: Color(r: 0, g: 0, b: 0, a: 120),
            modalTitleColor: Color(r: 20, g: 20, b: 20),
            modalTitleBarColor: Color(r: 220, g: 220, b: 220)
        )
    }
}

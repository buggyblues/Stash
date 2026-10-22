import XCTest
@testable import StashCore

/// Ports the test suite of the previous Electron build.
final class MaxItemsTests: XCTestCase {
    func testNormalizeKeepsPresetsAndCustomValuesAboveTheMinimum() {
        XCTAssertEqual(MaxItems.presets, [500, 1000, 2000])
        XCTAssertEqual(MaxItems.normalize(500), 500)
        XCTAssertEqual(MaxItems.normalize(1600), 1600)
        XCTAssertEqual(MaxItems.customMinimum, 500)
    }

    func testNormalizeTreatsZeroAsUnlimitedAndClampsSmallerValues() {
        XCTAssertEqual(MaxItems.normalize(0), 0)
        XCTAssertEqual(MaxItems.normalize(1), 500)
        XCTAssertEqual(MaxItems.normalize(499), 500)
        XCTAssertEqual(MaxItems.normalize(-100), 0)
    }

    func testAutoCleanupDeleteCount() {
        XCTAssertEqual(MaxItems.autoCleanupDeleteCount(count: 3200, maxItems: 0), 0)
        XCTAssertEqual(MaxItems.autoCleanupDeleteCount(count: 3200, maxItems: 2000), 1200)
        XCTAssertEqual(MaxItems.autoCleanupDeleteCount(count: 3200, maxItems: 499), 2700)
    }
}

final class LayoutModeTests: XCTestCase {
    func testCycleRotatesCenterToBottomToSideToCenter() {
        XCTAssertEqual(LayoutMode.center.next(), .bottom)
        XCTAssertEqual(LayoutMode.bottom.next(), .side)
        XCTAssertEqual(LayoutMode.side.next(), .center)
    }
}

final class ThemeTests: XCTestCase {
    func testResolveThemeMode() {
        XCTAssertEqual(ThemeMode.auto.resolved(systemTheme: .dark), .dark)
        XCTAssertEqual(ThemeMode.auto.resolved(systemTheme: .light), .light)
        XCTAssertEqual(ThemeMode.dark.resolved(systemTheme: .light), .dark)
        XCTAssertEqual(ThemeMode.light.resolved(systemTheme: .dark), .light)
    }
}

final class ShortcutTests: XCTestCase {
    func testMatchShortcutHandlesAltLetterShortcutsUsingPhysicalKeyIdentity() {
        let event = KeyEventInfo(
            key: "@",
            code: "KeyL",
            metaKey: false,
            ctrlKey: false,
            shiftKey: false,
            altKey: true
        )
        XCTAssertTrue(Shortcut.matches(event, "Alt+L"))
    }

    func testEventToShortcutRecordsAltLetterShortcutsFromPhysicalKeyIdentity() {
        let event = KeyEventInfo(
            key: "@",
            code: "KeyL",
            metaKey: false,
            ctrlKey: false,
            shiftKey: false,
            altKey: true
        )
        XCTAssertEqual(Shortcut.definition(from: event), "Alt+L")
    }

    func testFormatShortcutRendersSymbols() {
        XCTAssertEqual(Shortcut.display("Shift+CommandOrControl+V"), "⇧ ⌘ V")
        XCTAssertEqual(Shortcut.display("CommandOrControl+;"), "⌘ ;")
        XCTAssertEqual(Shortcut.display("CommandOrControl+,"), "⌘ ,")
        XCTAssertEqual(Shortcut.display("Alt+W"), "⌥ W")
        XCTAssertEqual(Shortcut.display("Alt"), "⌥")
        XCTAssertEqual(Shortcut.display("T"), "T")
    }

    func testModifierOnlyShortcutsMustBePressedAlone() {
        let alt = KeyEventInfo(key: "Alt", code: "AltLeft")
        XCTAssertTrue(Shortcut.matches(alt, "Alt"))
        let altWithShift = KeyEventInfo(key: "Alt", code: "AltLeft", shiftKey: true)
        XCTAssertFalse(Shortcut.matches(altWithShift, "Alt"))
    }
}

final class TransformerTests: XCTestCase {
    func testUpperAndLower() {
        XCTAssertEqual(Transformers.upper("hello"), "HELLO")
        XCTAssertEqual(Transformers.lower("HELLO"), "hello")
        XCTAssertEqual(Transformers.upper(""), "")
    }

    func testTitleUsesAsciiWordBoundaries() {
        XCTAssertEqual(Transformers.title("hello world"), "Hello World")
        XCTAssertEqual(Transformers.title("hello-world"), "Hello-World")
        XCTAssertEqual(Transformers.title("hello_world"), "Hello_world")
        XCTAssertEqual(Transformers.title("hELLO wORLD"), "HELLO WORLD")
        XCTAssertEqual(Transformers.title("123abc"), "123abc")
        XCTAssertEqual(Transformers.title("abc123def"), "Abc123def")
        XCTAssertEqual(Transformers.title("!!!hello!!!"), "!!!Hello!!!")
        XCTAssertEqual(Transformers.title(""), "")
    }

    func testCamel() {
        XCTAssertEqual(Transformers.camel("hello world"), "helloWorld")
        XCTAssertEqual(Transformers.camel("hello_world"), "helloWorld")
        XCTAssertEqual(Transformers.camel("hello-world"), "helloWorld")
        XCTAssertEqual(Transformers.camel("hello__world"), "helloWorld")
        XCTAssertEqual(Transformers.camel("hello_"), "hello")
        XCTAssertEqual(Transformers.camel("-hello"), "hello")
        XCTAssertEqual(Transformers.camel("Hello World"), "helloWorld")
        XCTAssertEqual(Transformers.camel("get_user_id"), "getUserId")
        XCTAssertEqual(Transformers.camel("XMLHttpRequest"), "xMLHttpRequest")
        XCTAssertEqual(Transformers.camel("123 abc"), "123Abc")
    }

    func testSnake() {
        XCTAssertEqual(Transformers.snake("helloWorld"), "hello_world")
        XCTAssertEqual(Transformers.snake("HelloWorld"), "hello_world")
        XCTAssertEqual(Transformers.snake("hello world"), "hello_world")
        XCTAssertEqual(Transformers.snake("hello  world"), "hello_world")
        XCTAssertEqual(Transformers.snake("hello_world"), "hello_world")
        XCTAssertEqual(Transformers.snake("getUserID"), "get_user_id")
        XCTAssertEqual(Transformers.snake("ABCDef"), "abcdef")
        XCTAssertEqual(Transformers.snake("foo2Bar"), "foo2bar")
    }

    func testKebab() {
        XCTAssertEqual(Transformers.kebab("helloWorld"), "hello-world")
        XCTAssertEqual(Transformers.kebab("hello_world"), "hello-world")
        XCTAssertEqual(Transformers.kebab("hello world"), "hello-world")
        XCTAssertEqual(Transformers.kebab("hello-world"), "hello-world")
        XCTAssertEqual(Transformers.kebab("a--b"), "a--b")
        XCTAssertEqual(Transformers.kebab("get_user_id"), "get-user-id")
    }

    func testTrimAndRemoveWhitespace() {
        XCTAssertEqual(Transformers.trim("  hello  "), "hello")
        XCTAssertEqual(Transformers.trim("a b  c"), "a b  c")
        XCTAssertEqual(Transformers.removeAllWhitespace("a b  c"), "abc")
        XCTAssertEqual(Transformers.removeAllWhitespace("a\nb\tc"), "abc")
    }
}

final class FormatterTests: XCTestCase {
    func testFormatJSON() {
        let valid = Formatters.formatJSON("{\"a\":1}")
        XCTAssertTrue(valid.valid)
        XCTAssertEqual(valid.formatted, "{\n  \"a\": 1\n}")

        let invalid = Formatters.formatJSON("{oops")
        XCTAssertFalse(invalid.valid)
        XCTAssertEqual(invalid.formatted, "{oops")
    }

    /// The pretty printed output has to match `JSON.stringify(value, null, 2)`.
    func testFormatJSONMatchesJavaScript() {
        let input = "{\"b\":1,\"a\":[1,{\"x\":true}],\"c\":\"hi\",\"d\":null,\"e\":{},\"f\":[]}"
        let expected = "{\n"
            + "  \"b\": 1,\n"
            + "  \"a\": [\n"
            + "    1,\n"
            + "    {\n"
            + "      \"x\": true\n"
            + "    }\n"
            + "  ],\n"
            + "  \"c\": \"hi\",\n"
            + "  \"d\": null,\n"
            + "  \"e\": {},\n"
            + "  \"f\": []\n"
            + "}"
        XCTAssertEqual(Formatters.formatJSON(input).formatted, expected)
    }

    func testFormatJSONKeepsTheKeyOrder() {
        let result = Formatters.formatJSON("{\"z\":1,\"a\":2,\"m\":3}")
        XCTAssertEqual(result.formatted, "{\n  \"z\": 1,\n  \"a\": 2,\n  \"m\": 3\n}")
    }

    func testDecodeBase64() {
        let result = Formatters.decodeBase64("aGVsbG8=")
        XCTAssertTrue(result.valid)
        XCTAssertEqual(result.decoded, "hello")

        let invalid = Formatters.decodeBase64("not valid base64!!")
        XCTAssertFalse(invalid.valid)
        XCTAssertEqual(invalid.decoded, "")
    }

    func testURLHelpers() {
        XCTAssertEqual(Formatters.decodeURL("https%3A%2F%2Fexample.com"), "https://example.com")
        XCTAssertEqual(Formatters.decodeURL("100%"), "100%")
    }
}

final class ContentDetectorTests: XCTestCase {
    func testDetectsURLs() {
        XCTAssertEqual(ContentDetector.detect("https://example.com").type, .url)
    }

    func testDetectsColors() {
        XCTAssertEqual(ContentDetector.detect("#FF7F43").type, .color)
        XCTAssertEqual(ContentDetector.detect("rgb(255, 127, 67)").type, .color)
        XCTAssertEqual(ContentDetector.detect("hsl(20, 100%, 63%)").type, .color)
    }

    func testDetectsJSON() {
        XCTAssertEqual(ContentDetector.detect("{\"a\": 1}").type, .json)
        XCTAssertEqual(ContentDetector.detect("{oops").type, .text)
    }

    func testDetectsFilePaths() {
        XCTAssertEqual(ContentDetector.detect("/usr/local/bin").type, .filePath)
        XCTAssertEqual(ContentDetector.detect("~/Documents").type, .filePath)
    }

    func testDetectsCode() {
        let result = ContentDetector.detect("function hello() {\n  return 1\n}")
        XCTAssertEqual(result.type, .code)
        XCTAssertEqual(result.metadata?["language"], "javascript")
    }

    func testPlainText() {
        XCTAssertEqual(ContentDetector.detect("hello world").type, .text)
    }
}

final class ColorParserTests: XCTestCase {
    func testParsesHexColours() {
        let color = ColorParser.parse("#FF7F43")
        XCTAssertNotNil(color)
        XCTAssertEqual(color?.hex, "#FF7F43")
        XCTAssertEqual(color?.rgbDisplay, "rgb(255, 127, 67)")
    }

    func testExpandsShortHex() {
        let color = ColorParser.parse("#abc")
        XCTAssertEqual(color?.hex, "#aabbcc")
    }

    func testDropsAlphaFromEightDigitHex() {
        let color = ColorParser.parse("#aabbccdd")
        XCTAssertEqual(color?.hex, "#aabbcc")
    }

    func testRejectsFourDigitHex() {
        XCTAssertNil(ColorParser.parse("#abcd"))
    }

    func testParsesRGBAndIgnoresAlpha() {
        let color = ColorParser.parse("rgba(255, 127, 67, 0.5)")
        XCTAssertEqual(color?.rgbDisplay, "rgb(255, 127, 67)")
    }

    func testRejectsNamedColours() {
        XCTAssertNil(ColorParser.parse("red"))
    }
}

final class SlugTests: XCTestCase {
    func testSlugRules() {
        XCTAssertEqual(Slug.make("Hello World"), "hello-world")
        XCTAssertEqual(Slug.make("  spaced  out  "), "spaced-out")
        XCTAssertEqual(Slug.make("--edge--"), "edge")
        XCTAssertEqual(Slug.make("a--b"), "a-b")
        XCTAssertEqual(Slug.make("C++"), "c++")
    }
}

final class JSONColorizerTests: XCTestCase {
    func testDetectsKeysAndValues() {
        let fragments = JSONColorizer.tokenize("{\"key\": \"value\", \"n\": 1, \"b\": true, \"z\": null}")
        XCTAssertTrue(fragments.contains { $0.kind == .key && $0.text == "\"key\"" })
        XCTAssertTrue(fragments.contains { $0.kind == .string && $0.text == "\"value\"" })
        XCTAssertTrue(fragments.contains { $0.kind == .number })
        XCTAssertTrue(fragments.contains { $0.kind == .boolean })
        XCTAssertTrue(fragments.contains { $0.kind == .null })
    }
}

final class LocalizationTests: XCTestCase {
    func testEveryBundleExposesTheSameKeys() {
        let canonical = Set(Locales.zhCN.keys)
        XCTAssertEqual(Set(Locales.english.keys), canonical)
        XCTAssertEqual(Set(Locales.zhTW.keys), canonical)
    }

    func testInterpolation() {
        let text = Localization.interpolate("{{count}} items", ["count": "3"])
        XCTAssertEqual(text, "3 items")
    }
}

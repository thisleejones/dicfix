import XCTest
@testable import dicfix

class KeycodeMapperTests: XCTestCase {

    func testValidFunctionKey() {
        // Test a few valid function keys to ensure they return the correct keycode.
        XCTAssertEqual(KeycodeMapper.keyCode(for: "F1"), 122, "F1 should map to keycode 122")
        XCTAssertEqual(KeycodeMapper.keyCode(for: "F5"), 96, "F5 should map to keycode 96")
        XCTAssertEqual(KeycodeMapper.keyCode(for: "F12"), 111, "F12 should map to keycode 111")
        XCTAssertEqual(KeycodeMapper.keyCode(for: "F20"), 90, "F20 should map to keycode 90")
    }

    func testCaseInsensitiveFunctionKey() {
        // Test that the lookup is case-insensitive.
        XCTAssertEqual(KeycodeMapper.keyCode(for: "f1"), 122, "f1 should be treated the same as F1")
        XCTAssertEqual(KeycodeMapper.keyCode(for: "f5"), 96, "f5 should be treated the same as F5")
    }

    func testInvalidFunctionKey() {
        // Test a function key that does not exist in our map.
        XCTAssertNil(KeycodeMapper.keyCode(for: "F21"), "F21 is not a supported key and should return nil")
        XCTAssertNil(KeycodeMapper.keyCode(for: "NotAKey"), "An arbitrary string should return nil")
    }

    func testNonFunctionKey() {
        // Test a key that exists in the map but is not a function key.
        XCTAssertEqual(KeycodeMapper.keyCode(for: "Command"), 55, "Command key should map to 55")
        XCTAssertEqual(KeycodeMapper.keyCode(for: "'"), 39, "Apostrophe key should map to 39")
    }

    func testEmptyString() {
        // Test that an empty string returns nil.
        XCTAssertNil(KeycodeMapper.keyCode(for: ""), "Empty string should return nil")
    }
}

// Copyright (c) 2025 Lee Jones
// Licensed under the MIT License. See LICENSE file in the project root for details.

import XCTest
@testable import dicfix
import SwiftUI

class ColorMapperTests: XCTestCase {

    func testParseColor_withValidNamedColor() {
        let color = ColorMapper.parseColor("red")
        XCTAssertEqual(color, .red)
    }

    func testParseColor_withValidNamedColor_caseInsensitive() {
        let color = ColorMapper.parseColor("ReD")
        XCTAssertEqual(color, .red)
    }
    
    func testParseColor_withValidSystemColor_caseInsensitive() {
        let color = ColorMapper.parseColor("labelColor")
        XCTAssertEqual(color, Color(nsColor: .labelColor))
        
        let color2 = ColorMapper.parseColor("lAbElCoLoR")
        XCTAssertEqual(color2, Color(nsColor: .labelColor))
    }

    func testParseColor_withValidHexColor() {
        let color = ColorMapper.parseColor("#FF0000")
        XCTAssertEqual(color, Color(red: 1.0, green: 0, blue: 0))
    }
    
    func testParseColor_withValidShortHexColor() {
        let color = ColorMapper.parseColor("#f00")
        XCTAssertEqual(color, Color(red: 1.0, green: 0, blue: 0))
    }

    func testParseColor_withInvalidColor() {
        let color = ColorMapper.parseColor("not a color")
        XCTAssertEqual(color, .gray) // Falls back to gray
    }

    func testParseColor_withInvalidColor_withCustomFallback() {
        let color = ColorMapper.parseColor("not a color", fallback: .blue)
        XCTAssertEqual(color, .blue)
    }

    func testParseColor_withEmptyString() {
        let color = ColorMapper.parseColor("")
        XCTAssertEqual(color, .gray) // Falls back to gray
    }
}

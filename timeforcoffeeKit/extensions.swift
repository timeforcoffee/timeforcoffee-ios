//
//  extensions.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 24.02.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import UIKit

public typealias replyClosure = (([NSObject : AnyObject]!) -> Void)

public extension UIColor {
    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")
        
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }
    
    convenience init(netHex:Int) {
        self.init(red:(netHex >> 16) & 0xff, green:(netHex >> 8) & 0xff, blue:netHex & 0xff)
    }
    
    convenience init(netHexString: String) {
        var cString:String = netHexString.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet() as NSCharacterSet).uppercaseString
        
        if (cString.hasPrefix("#")) {
            cString = cString.substringFromIndex(advance(cString.startIndex, 1))
        }
        var rgbValue:UInt32 = 0
        NSScanner(string: cString).scanHexInt(&rgbValue)
        
        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
}



struct Regex {
    var pattern: String {
        didSet {
            updateRegex()
        }
    }
    var expressionOptions: NSRegularExpressionOptions {
        didSet {
            updateRegex()
        }
    }
    var matchingOptions: NSMatchingOptions
    
    var regex: NSRegularExpression?
    
    init(pattern: String, expressionOptions: NSRegularExpressionOptions, matchingOptions: NSMatchingOptions) {
        self.pattern = pattern
        self.expressionOptions = expressionOptions
        self.matchingOptions = matchingOptions
        updateRegex()
    }
    
    init(pattern: String) {
        self.pattern = pattern
        expressionOptions = NSRegularExpressionOptions(0)
        matchingOptions = NSMatchingOptions(0)
        updateRegex()
    }
    
    mutating func updateRegex() {
        regex = NSRegularExpression(pattern: pattern, options: expressionOptions, error: nil)
    }
}


extension String {
    func matchRegex(pattern: Regex) -> Bool {
        let range: NSRange = NSMakeRange(0, countElements(self))
        if pattern.regex != nil {
            let matches: [AnyObject] = pattern.regex!.matchesInString(self, options: pattern.matchingOptions, range: range)
            return matches.count > 0
        }
        return false
    }
    
    func match(patternString: String) -> Bool {
        return self.matchRegex(Regex(pattern: patternString))
    }
    
    func replaceRegex(pattern: Regex, template: String) -> String {
        if self.matchRegex(pattern) {
            let range: NSRange = NSMakeRange(0, countElements(self))
            if pattern.regex != nil {
                return pattern.regex!.stringByReplacingMatchesInString(self, options: pattern.matchingOptions, range: range, withTemplate: template)
            }
        }
        return self
    }
    
    func replace(pattern: String, template: String) -> String {
        return self.replaceRegex(Regex(pattern: pattern), template: template)
    }
}

public extension UIImage {

func imageByApplyingAlpha(alpha: CGFloat) -> UIImage {

    UIGraphicsBeginImageContextWithOptions(self.size, false, 0.0);

    let ctx = UIGraphicsGetCurrentContext();
    let area = CGRectMake(0, 0, self.size.width, self.size.height);

    CGContextScaleCTM(ctx, 1, -1);
    CGContextTranslateCTM(ctx, 0, -area.size.height);

    CGContextSetBlendMode(ctx, kCGBlendModeMultiply);

    CGContextSetAlpha(ctx, alpha);

    CGContextDrawImage(ctx, area, self.CGImage);

    let newImage = UIGraphicsGetImageFromCurrentImageContext();

    UIGraphicsEndImageContext();

    return newImage;
    }


}

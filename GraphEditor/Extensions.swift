//import Foundation
//import CoreGraphics
//
//public extension Float {
//  /// Returns a random floating point number between 0.0 and 1.0, inclusive.
//  static var random: Float {
//    Float(arc4random()) / 0xFFFFFFFF
//  }
//
//  /// Random float between 0 and n-1.
//  ///
//  /// - parameter n:  Interval max
//  /// - returns: Returns a random float point number between 0 and n max
//  static func random(min: Float, max: Float) -> Float {
//    Float.random * (max - min) + min
//  }
//}
//
//public extension CGFloat {
//  /// Randomly returns either 1.0 or -1.0.
//  static var randomSign: CGFloat {
//    (arc4random_uniform(2) == 0) ? 1.0 : -1.0
//  }
//
//  /// Returns a random floating point number between 0.0 and 1.0, inclusive.
//  static var random: CGFloat {
//    CGFloat(Float.random)
//  }
//
//  /// Random CGFloat between 0 and n-1.
//  ///
//  /// - parameter n:  Interval max
//  /// - returns: A random CGFloat point number between 0 and n max
//  static func random(min: CGFloat, max: CGFloat) -> CGFloat {
//    CGFloat.random * (max - min) + min
//  }
//}
//
//
//import SwiftUI
//
//extension View {
//  /// The radius to use when drawing rounded corners for the view background.
//  func cornerRadius(_ radius: CGFloat) -> some View {
//    clipShape(RoundedRectangle.init(cornerRadius: radius, style: .circular))
//  }
//
//  /// Applies the default box shadow for the patch nodes.
//  func patchShadow() -> some View {
//    shadow(color: Color(hex: 0x000, alpha: 0.2), radius: 4, x: 0, y: 2)
//  }
//
//  /// Adds an rounded rectangle overlay to the view.
//  func roundedBorder(radius: CGFloat, hidden: Bool = false, color: Color) -> some View {
//    overlay(RoundedRectangle(cornerRadius: radius).stroke(color, lineWidth: hidden ? 0 : 2))
//  }
//
//  /// Applies the given transform if the given condition evaluates to `true`.
//  /// - parameter condition: The condition to evaluate.
//  /// - parameter transform: The transform to apply to the source `View`.
//  /// - returns: Either the original `View` or the modified `View` if the condition is `true`.
//  @ViewBuilder
//  func when<C: View>(_ condition: Bool, transform: (Self) -> C) -> some View {
//    if condition {
//        transform(self)
//      } else {
//        self
//      }
//    }
//}

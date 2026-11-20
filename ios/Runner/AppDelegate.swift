import Flutter
import UIKit
import GoogleMobileAds

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Shared so the factory instance lives as long as the app process.
  private let nativeAdFactory = PicturegamesNativeAdFactory()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerNativeAdFactory(engineBridge.pluginRegistry)
  }

  /// The Dart side requests native ads with factoryId
  /// AdsService.nativeAdFactoryId ("picturegames_native"); without this
  /// registration the plugin errors on every load and the native ad slots
  /// stay permanently empty.
  ///
  /// The plugin's SPM package exposes no public headers, so
  /// `GoogleMobileAdsPlugin` is not visible to Swift — the class is reached
  /// through the Objective-C runtime instead. Registration silently no-ops
  /// if the plugin class is ever missing (native ads just don't fill).
  private func registerNativeAdFactory(_ registry: any FlutterPluginRegistry) {
    guard
      let pluginClass = NSClassFromString("GoogleMobileAdsPlugin") as? NSObject.Type,
      let method = class_getClassMethod(
        pluginClass,
        NSSelectorFromString("registerNativeAdFactory:factoryId:nativeAdFactory:"))
    else {
      debugPrint("[ads] GoogleMobileAdsPlugin not linked — native ads disabled")
      return
    }
    typealias RegisterFn = @convention(c) (
      AnyObject, Selector, Any, NSString, Any
    ) -> Bool
    let fn = unsafeBitCast(method, to: RegisterFn.self)
    let registered = fn(
      pluginClass,
      NSSelectorFromString("registerNativeAdFactory:factoryId:nativeAdFactory:"),
      registry,
      "picturegames_native" as NSString,
      nativeAdFactory
    )
    if !registered {
      debugPrint("[ads] native ad factory registration failed (duplicate id?)")
    }
  }
}

/// Builds the platform view for picturegames_native ads: icon + headline +
/// body + CTA, styled with the app's palette (ink #192B45, purple #7057E8).
/// Exposed @objc with the createNativeAd:customOptions: selector the plugin
/// calls on registered factories.
@objc class PicturegamesNativeAdFactory: NSObject {
  @objc func createNativeAd(
    _ nativeAd: NativeAd,
    customOptions: [AnyHashable: Any]?
  ) -> NativeAdView? {
    let adView = NativeAdView()

    let icon = UIImageView()
    icon.contentMode = .scaleAspectFit
    icon.layer.cornerRadius = 8
    icon.clipsToBounds = true

    let headline = UILabel()
    headline.font = .boldSystemFont(ofSize: 14)
    headline.textColor = UIColor(red: 0x19 / 255.0, green: 0x2B / 255.0, blue: 0x45 / 255.0, alpha: 1)
    headline.numberOfLines = 1

    let body = UILabel()
    body.font = .systemFont(ofSize: 12)
    body.textColor = .secondaryLabel
    body.numberOfLines = 2

    let cta = UIButton(type: .system)
    cta.backgroundColor = UIColor(red: 0x70 / 255.0, green: 0x57 / 255.0, blue: 0xE8 / 255.0, alpha: 1)
    cta.setTitleColor(.white, for: .normal)
    cta.titleLabel?.font = .boldSystemFont(ofSize: 12)
    cta.layer.cornerRadius = 8
    cta.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

    // Layout: [icon | headline+body | CTA], pinned inside the ad view.
    let textColumn = UIStackView(arrangedSubviews: [headline, body])
    textColumn.axis = .vertical
    textColumn.spacing = 2

    let row = UIStackView(arrangedSubviews: [icon, textColumn, cta])
    row.axis = .horizontal
    row.alignment = .center
    row.spacing = 10
    row.translatesAutoresizingMaskIntoConstraints = false
    adView.addSubview(row)
    NSLayoutConstraint.activate([
      row.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 12),
      row.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -12),
      row.topAnchor.constraint(equalTo: adView.topAnchor, constant: 10),
      row.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -10),
      icon.widthAnchor.constraint(equalToConstant: 40),
      icon.heightAnchor.constraint(equalToConstant: 40),
      cta.widthAnchor.constraint(greaterThanOrEqualToConstant: 88),
    ])

    headline.text = nativeAd.headline
    body.text = nativeAd.body
    if let ctaText = nativeAd.callToAction {
      cta.setTitle(ctaText, for: .normal)
    }
    if let iconImage = nativeAd.icon?.image {
      icon.image = iconImage
    } else {
      icon.isHidden = true
    }

    adView.iconView = icon
    adView.headlineView = headline
    adView.bodyView = body
    adView.callToActionView = cta
    adView.nativeAd = nativeAd
    return adView
  }
}

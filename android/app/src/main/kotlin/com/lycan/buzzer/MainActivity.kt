package com.lycan.buzzer

import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import io.flutter.plugins.googlemobileads.NativeAdFactory

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The Dart side requests native ads with factoryId AdsService.nativeAdFactoryId
        // ("picturegames_native"); without this registration the plugin errors on
        // every load and the native ad slots stay permanently empty.
        registerNativeAdFactory(flutterEngine, attempt = 0)
    }

    /** Registration can race the plugin's own attach — retry briefly. */
    private fun registerNativeAdFactory(flutterEngine: FlutterEngine, attempt: Int) {
        try {
            GoogleMobileAdsPlugin.registerNativeAdFactory(
                flutterEngine, AD_FACTORY_ID, NativeAdFactoryImpl(layoutInflater))
        } catch (err: Exception) {
            if (attempt < 5) {
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    registerNativeAdFactory(flutterEngine, attempt + 1)
                }, 200)
            } else {
                android.util.Log.e("NativeAds", "Could not register native ad factory", err)
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, AD_FACTORY_ID)
    }

    companion object {
        const val AD_FACTORY_ID = "picturegames_native"
    }
}

/** Builds the platform view for picturegames_native ads: icon + headline +
 * body + CTA, styled with the app's palette. */
class NativeAdFactoryImpl(private val layoutInflater: LayoutInflater) : NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?,
    ): NativeAdView {
        val adView =
            layoutInflater.inflate(R.layout.native_ad, null) as NativeAdView
        val headline = adView.findViewById<TextView>(R.id.ad_headline)
        val body = adView.findViewById<TextView>(R.id.ad_body)
        val cta = adView.findViewById<Button>(R.id.ad_cta)
        val icon = adView.findViewById<ImageView>(R.id.ad_icon)

        headline.text = nativeAd.headline
        body.text = nativeAd.body
        cta.text = nativeAd.callToAction
        val iconDrawable = nativeAd.icon?.drawable
        if (iconDrawable != null) {
            icon.setImageDrawable(iconDrawable)
        } else {
            icon.visibility = View.GONE
        }

        adView.headlineView = headline
        adView.bodyView = body
        adView.callToActionView = cta
        adView.iconView = icon
        adView.setNativeAd(nativeAd)
        return adView
    }
}

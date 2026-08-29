# R8 rules for the release build (Flutter's Gradle plugin minifies release by default).

# flutter_stripe ships a push-provisioning bridge (adding cards to Google Wallet)
# that this app never uses. Its code references Stripe classes that only exist
# in the optional `stripe-android-issuing-push-provisioning` artifact, whose own
# dependency (`play-services-tapandpay`) is not on any public repository — so
# the classes are absent at R8 time and R8 refuses to finish. Warning, not keep:
# nothing needs to be preserved, the references simply lead nowhere.
-dontwarn com.stripe.android.pushProvisioning.**

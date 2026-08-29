/// The Stripe **publishable** key — public information, by Stripe's own
/// design.
///
/// It identifies the account to the card sheet and can do nothing on its own:
/// it cannot move money, read a customer, or see a card. That is why it lives
/// in the build rather than in a secret store, exactly as the endpoint URL
/// does. The key that *can* do those things is `sk_…`, and it exists only as a
/// Cloudflare Worker secret — see `docs/BILLING_API.md`, 「秘密の置き場」.
///
/// This is the **test** key. Replacing it with the live `pk_live_…` at release
/// is the one change this file needs, and it has to happen in the same release
/// as the Worker's `STRIPE_SECRET_KEY` switching to its live counterpart — a
/// test key against a live secret fails at the SetupIntent, and the other way
/// round charges nothing.
const kStripePublishableKey =
    'pk_test_51U9duQAPhpIXWYKDgizN5lwnK7vYTYCxkobH8c5VoTkU1H8Moz0hYepyusCWWjvwJx3dYVGDGAw6zTqFWpAANuzM00EWieWdwT';

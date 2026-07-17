// lib/l10n/app_strings.dart
//
// Translation dictionaries for the Parent Payment app.
// Mirrors the structure of the web frontend's src/i18n/translations.js so
// the two stay easy to keep in sync as more screens get wired up.
//
// Coverage right now: Login screen (the screen wired up in this pass).
// Add more keys here as more screens are localized — every screen pulls
// from this same map via LanguageService.t(), no per-screen setup needed.

const Map<String, Map<String, String>> appStrings = {
  'en': {
    'app_title': 'Parent Portal',
    'login_email_label': 'Email Address',
    'login_invalid_email': 'Enter a valid email address',
    'login_send_otp_failed': 'Failed to send OTP',
    'login_send_code': 'Send Verification Code',
    'payment_processing_title': 'Payment Processing',
    'payment_processing_body':
        'Your payment is being processed. It will appear in your payment history shortly.',
    'payment_successful_title': 'Payment Successful!',
    'payment_verifying': 'Verifying your payment...',
    'please_wait': 'Please wait...',
    'ok': 'OK',
  },
  'am': {
    'app_title': 'የወላጅ መግቢያ',
    'login_email_label': 'የኢሜይል አድራሻ',
    'login_invalid_email': 'ትክክለኛ የኢሜይል አድራሻ ያስገቡ',
    'login_send_otp_failed': 'ኮዱን መላክ አልተሳካም',
    'login_send_code': 'የማረጋገጫ ኮድ ላክ',
    'payment_processing_title': 'ክፍያ በሂደት ላይ',
    'payment_processing_body':
        'ክፍያዎ በሂደት ላይ ነው። በቅርቡ በክፍያ ታሪክዎ ውስጥ ይታያል።',
    'payment_successful_title': 'ክፍያ ተሳክቷል!',
    'payment_verifying': 'ክፍያዎን በማረጋገጥ ላይ...',
    'please_wait': 'እባክዎ ይጠብቁ...',
    'ok': 'እሺ',
  },
  'om': {
    'app_title': 'Portaalii Warraa',
    'login_email_label': 'Teessoo Imeelii',
    'login_invalid_email': 'Teessoo imeelii sirrii galchaa',
    'login_send_otp_failed': 'Lakkoofsa ergu hin dandeenye',
    'login_send_code': 'Lakkoofsa Mirkaneessaa Ergi',
    'payment_processing_title': 'Kaffaltiin Adeemsifamaa Jira',
    'payment_processing_body':
        'Kaffaltiin keessan adeemsifamaa jira. Yeroo dhihootti seenaa kaffaltii keessan keessatti ni mul\'ata.',
    'payment_successful_title': 'Kaffaltiin Milkaa\'eera!',
    'payment_verifying': 'Kaffaltii keessan mirkaneessaa jira...',
    'please_wait': 'Maaloo eegaa...',
    'ok': 'Tole',
  },
};

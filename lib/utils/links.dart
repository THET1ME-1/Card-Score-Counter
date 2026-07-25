import 'package:url_launcher/url_launcher.dart';

/// Внешние ссылки приложения: репозиторий и способы поддержать разработку.
/// Собраны в одном месте, чтобы адрес не приходилось искать по экранам.

/// Публичный репозиторий приложения.
final Uri kRepoUrl = Uri.parse('https://github.com/THET1ME-1/Card-Score-Counter');

/// Подписка на Boosty.
final Uri kBoostyUrl = Uri.parse('https://boosty.to/sntcompany');

/// DonationAlerts — разовый донат картой или через СБП.
final Uri kDonationAlertsUrl =
    Uri.parse('https://www.donationalerts.com/r/thet1me');

/// Lava.top — разовый перевод внутри страны.
final Uri kLavaDonateUrl =
    Uri.parse('https://app.lava.top/togetherly-store?tabId=donate');

Future<void> openRepo() =>
    launchUrl(kRepoUrl, mode: LaunchMode.externalApplication);

Future<void> openSupportAuthors() =>
    launchUrl(kBoostyUrl, mode: LaunchMode.externalApplication);

Future<void> openDonationAlerts() =>
    launchUrl(kDonationAlertsUrl, mode: LaunchMode.externalApplication);

Future<void> openLavaDonate() =>
    launchUrl(kLavaDonateUrl, mode: LaunchMode.externalApplication);

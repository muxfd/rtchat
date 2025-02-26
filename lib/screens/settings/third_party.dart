import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:rtchat/components/scanner_error.dart';
import 'package:rtchat/components/scanner_settings.dart';
import 'package:rtchat/models/adapters/donations.dart';
import 'package:rtchat/models/user.dart';
import 'package:rtchat/urls.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';



const streamlabsCurrencies = [
  [null, "Donation's currency"],
  ['AUD', 'Australian Dollar'],
  ['BRL', 'Brazilian Real'],
  ['CAD', 'Canadian Dollar'],
  ['CZK', 'Czech Koruna'],
  ['DKK', 'Danish Krone'],
  ['EUR', 'Euro'],
  ['HKD', 'Hong Kong Dollar'],
  ['ILS', 'Israeli New Sheqel'],
  ['MYR', 'Malaysian Ringgit'],
  ['MXN', 'Mexican Peso'],
  ['NOK', 'Norwegian Krone'],
  ['NZD', 'New Zealand Dollar'],
  ['PHP', 'Philippine Peso'],
  ['PLN', 'Polish Zloty'],
  ['GBP', 'Pound Sterling'],
  ['RUB', 'Russian Ruble'],
  ['SGD', 'Singapore Dollar'],
  ['SEK', 'Swedish Krona'],
  ['CHF', 'Swiss Franc'],
  ['THB', 'Thai Baht'],
  ['TRY', 'Turkish Lira'],
  ['USD', 'US Dollar']
];

class _RealtimeCashWidget extends StatefulWidget {
  final String userId;

  const _RealtimeCashWidget({required this.userId});

  @override
  State<_RealtimeCashWidget> createState() => _RealtimeCashWidgetState();
}

class _RealtimeCashWidgetState extends State<_RealtimeCashWidget> {
  var _scanController = MobileScannerController(
    // facing: CameraFacing.back,
    // torchEnabled: false,
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: DonationsAdapter.instance
          .forRealtimeChatAddress(userId: widget.userId),
      builder: (context, snapshot) {
        return Column(children: [
          ListTile(
            leading: const Image(image: AssetImage('assets/realtimecash.png')),
            title: const Text("RealtimeCash"),
            subtitle: const Text("Connect an ETH or MATIC wallet"),
            trailing: SizedBox(
              width: 24,
              height: 24,
              child: snapshot.data != null
                  ? const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    )
                  : const Icon(Icons.help),
            ),
            // open https://cash.rtirl.com/
            onTap: () => openUrl(Uri.parse("https://cash.rtirl.com/")),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 88, right: 16),
            child: TextField(
                controller: TextEditingController()..text = snapshot.data ?? "",
                readOnly: true,
                decoration: InputDecoration(
                    hintText: "Wallet address",
                    suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: () {
                          final messenger = ScaffoldMessenger.of(context);

                          showModalBottomSheet(
                            isScrollControlled: true,
                            context: context,
                            builder: (ctx) {
                              return Stack(
                                children: [
                                  MobileScanner(
                                    errorBuilder: (context, error, child) {
                                      return ScannerErrorWidget(error: error);
                                    },
                                    controller: _scanController,
                                    onDetect: (capture) {
                                      final List<Barcode> barcodes =
                                          capture.barcodes;

                                      if (barcodes.isEmpty) {
                                        messenger.showSnackBar(SnackBar(
                                            content: Text(
                                                AppLocalizations.of(context)!
                                                    .invalidUrlErrorText)));
                                      }

                                      final barcode = barcodes.first;

                                      if (barcode.rawValue == null ||
                                          barcode.rawValue!.isEmpty) {
                                        messenger.showSnackBar(SnackBar(
                                            content: Text(
                                                AppLocalizations.of(context)!
                                                    .invalidUrlErrorText)));

                                        Navigator.pop(ctx);
                                      }

                                      DonationsAdapter.instance
                                          .setRealtimeCashAddress(
                                              address: barcode.rawBytes
                                                  .toString()
                                                  .toLowerCase());

                                      Navigator.pop(ctx);
                                    },
                                  ),
                                  Positioned(
                                      top: 50,
                                      left: 0,
                                      right: 0,
                                      child: ScannerSettings(
                                        scanController: _scanController,
                                      )),
                                ],
                              );
                            },
                          ).then((value) {
                            _scanController.dispose();

                            _scanController = MobileScannerController(
                              detectionSpeed: DetectionSpeed.noDuplicates,
                            );
                          });
                        })),
                keyboardType: TextInputType.url),
          ),
        ]);
      },
    );
  }
}

class _StreamlabsWidget extends StatelessWidget {
  final String userId;

  const _StreamlabsWidget({required this.userId});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Image(image: AssetImage('assets/streamlabs.png')),
      trailing: SizedBox(
        width: 24,
        height: 24,
        child: StreamBuilder(
          stream: DonationsAdapter.instance.forStreamlabsConfig(userId: userId),
          builder: (context, snapshot) {
            return snapshot.data != null
                ? const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  )
                : Container();
          },
        ),
      ),
      title: const Text("Streamlabs"),
      subtitle: const Text("See your Streamlabs donations"),
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        final userModel = Provider.of<UserModel>(context, listen: false);
        final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
        final provider = userModel.userChannel?.provider;
        if (provider == null) {
          messenger.showSnackBar(const SnackBar(
              content: Text(
                  "Some strange authentication error occurred. Try signing out, or ask on Discord?")));
          return;
        }
        final result = await FlutterWebAuth2.authenticate(
            url:
                "https://chat.rtirl.com/auth/streamlabs/redirect?token=$idToken&provider=$provider",
            callbackUrlScheme: "com.rtirl.chat");
        final token = Uri.parse(result).queryParameters['token'];
        if (token == null) {
          messenger.showSnackBar(const SnackBar(
            content:
                Text("Hmm, that didn't work. Try again, or ask on Discord?"),
          ));
        }
      },
    );
  }
}

class _StreamElementsWidget extends StatelessWidget {
  final String userId;

  const _StreamElementsWidget({required this.userId});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Image(image: AssetImage('assets/streamelements.png')),
      trailing: SizedBox(
        width: 24,
        height: 24,
        child: StreamBuilder(
          stream:
              DonationsAdapter.instance.forStreamElementsConfig(userId: userId),
          builder: (context, snapshot) {
            return snapshot.data != null
                ? const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  )
                : Container();
          },
        ),
      ),
      title: const Text("StreamElements"),
      subtitle: const Text("See your StreamElements donations"),
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        final userModel = Provider.of<UserModel>(context, listen: false);
        final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
        final provider = userModel.userChannel?.provider;
        if (provider == null) {
          messenger.showSnackBar(const SnackBar(
              content: Text(
                  "Some strange authentication error occurred. Try signing out, or ask on Discord?")));
          return;
        }
        final result = await FlutterWebAuth2.authenticate(
            url:
                "https://chat.rtirl.com/auth/streamelements/redirect?token=$idToken&provider=$provider",
            callbackUrlScheme: "com.rtirl.chat");
        final token = Uri.parse(result).queryParameters['token'];
        if (token == null) {
          messenger.showSnackBar(const SnackBar(
            content:
                Text("Hmm, that didn't work. Try again, or ask on Discord?"),
          ));
        }
      },
    );
  }
}

class ThirdPartyScreen extends StatelessWidget {
  const ThirdPartyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("Third-party services")),
        body: Consumer<UserModel>(
          builder: (context, userModel, child) {
            final userId = userModel.user?.uid;
            if (userId == null) {
              // the user should be signed in at this point.
              return Container();
            }
            return ListView(
              children: [
                _RealtimeCashWidget(userId: userId),
                const Divider(),
                _StreamlabsWidget(userId: userId),
                const Divider(),
                _StreamElementsWidget(userId: userId),
              ],
            );
          },
        ));
  }
}

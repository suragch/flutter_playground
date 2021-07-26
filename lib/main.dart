import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

void main() {
  setUpGetIt();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const ShopPageList(),
    );
  }
}

class ShopPageList extends StatefulWidget {
  const ShopPageList({Key? key}) : super(key: key);

  @override
  _ShopPageListState createState() => _ShopPageListState();
}

class _ShopPageListState extends State<ShopPageList> {
  @override
  void initState() {
    getIt<ShopNotifier>().init();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = getIt<ShopNotifier>();
    return ValueListenableBuilder<List<Shop>>(
      valueListenable: notifier,
      builder: (context, shopList, child) {
        return Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(children: [] //shopCardList,
                  ),
            ),
          ),
        );
      },
    );
  }
}

class ShopNotifier extends ValueNotifier<List<Shop>> {
  ShopNotifier() : super(_initialShopList);

  static const List<Shop> _initialShopList = [];

  Future<void> init() async {
    final shopService = getIt<ShopService>();
    value = await shopService.getShopList();
  }
}

class Shop {}

final getIt = GetIt.instance;

void setUpGetIt() {
  // service layer
  getIt.registerLazySingleton<ShopService>(() => FakeShopService());
  // state management layer
  getIt.registerLazySingleton<ShopNotifier>(() => ShopNotifier());
}

abstract class ShopService {
  Future<List<Shop>> getShopList();
}

class FakeShopService implements ShopService {
  @override
  Future<List<Shop>> getShopList() async {
    await Future.delayed(Duration(seconds: 3));
    return [Shop(), Shop(), Shop()];
  }
}

// class RealShopService implements ShopService {
//   @override
//   Future<List<Shop>> getShopList() async {
//     // TODO: contact server and get JSON shop list
//     // TODO: convert JSON to List<Shop>
//   }
// }

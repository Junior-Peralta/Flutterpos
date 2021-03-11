import 'package:localstorage/localstorage.dart' as lib;

import '../common/common.dart';
import '../provider/src.dart';
import 'connection_interface.dart';

class LocalStorage implements DatabaseConnectionInterface {
  final lib.LocalStorage ls;

  LocalStorage(String name, [String? path, Map<String, dynamic>? initialData])
      : ls = lib.LocalStorage(name, path, initialData);

  @override
  Future<bool> open() => ls.ready;

  @override
  Future<int> nextUID() async {
    // if empty, starts from -1
    int current = ls.getItem('order_id_highkey') ?? -1;
    await ls.setItem('order_id_highkey', ++current);
    return current;
  }

  @override
  Future<void> insert(Order order) {
    if (order.id < 0) throw 'Invalid order ID';
    final checkoutTime = Common.extractYYYYMMDD(order.checkoutTime);

    // current orders of the day that have been saved
    // if this is first order then create it as an List
    var orders = ls.getItem(checkoutTime);
    if (orders != null) {
      orders.add(order.toJson());
    } else {
      orders = [order.toJson()];
    }
    return ls.setItem(checkoutTime, orders);
  }

  @override
  List<Order> get(DateTime day) {
    List<dynamic>? storageData = ls.getItem(Common.extractYYYYMMDD(day));
    if (storageData == null) return [];
    return storageData.map((i) => Order.fromJson(i)).toList();
  }

  @override
  List<Order> getRange(DateTime start, DateTime end) {
    return List.generate(
      end.difference(start).inDays + 1,
      (i) => get(DateTime(start.year, start.month, start.day + i)),
    ).expand((e) => e).toList();
  }

  @override
  Menu? getMenu() {
    var storageData = ls.getItem('menu');
    if (storageData == null) {
      print('\x1B[94mmenu not found in localstorage\x1B[0m');
      return null;
    }
    return Menu.fromJson(storageData as Map<String, dynamic>);
  }

  @override
  Future<void> setMenu(Menu newMenu) {
    // to set items to local storage
    return ls.setItem('menu', newMenu);
  }

  @override
  Future<Order> delete(DateTime day, int orderID) async {
    final orders = get(day);
    final deletedOrder = orders.firstWhere((e) => e.id == orderID)..isDeleted = true;
    await ls.setItem(Common.extractYYYYMMDD(day), orders.map((e) => e.toJson()).toList());
    return deletedOrder;
  }

  @override
  Future<void> destroy() => ls.clear();

  @override
  void close() => ls.dispose();

  @override
  Future<void> setCoordinate(int tableID, double x, double y) {
    return Future.wait(
      [ls.setItem('${tableID}_coord_x', x), ls.setItem('${tableID}_coord_y', y)],
      eagerError: true,
    );
  }

  @override
  double getX(int tableID) {
    return ls.getItem('${tableID}_coord_x') ?? 0;
  }

  @override
  double getY(int tableID) {
    return ls.getItem('${tableID}_coord_y') ?? 0;
  }

  @override
  Future<List<int>> addTable(int tableID) async {
    final list = tableIDs();
    list.add(tableID);
    await ls.setItem('table_list', list);
    return list;
  }

  @override
  Future<List<int>> removeTable(int tableID) async {
    final list = tableIDs();
    list.remove(tableID);
    await ls.setItem('table_list', list);
    return list;
  }

  @override
  List<int> tableIDs() {
    final List<dynamic> l = ls.getItem('table_list') ?? [];
    return l.cast<int>();
  }
}
# AI Prompt Challenge

Buatkan halaman Flutter bernama StatsPage menggunakan flutter_riverpod.
Requirements:
- ConsumerWidget dengan satu AsyncNotifierProvider yang mensimulasikan
  pengambilan data statistik (delay 2 detik, kadang gagal 30%).
- UI harus menangani loading (spinner), error (pesan + tombol retry),
  dan success (ListView 3 item).
- Berikan unit test untuk notifier-nya.
Jelaskan setiap bagian kode dalam komentar.


# AI Verification Checklist

Apakah state diubah secara immutable (tidak ada state.add() atau mutasi list langsung)?
Apakah ref.watch hanya dipakai di dalam build, dan ref.read di callback?
Apakah ketiga state AsyncValue benar-benar ditangani (bukan hanya success)?
Apakah provider dideklarasikan dengan tipe eksplisit dan tidak duplikat dengan provider lain?
Apakah kode AI memakai API Riverpod versi lama (StateProvider antipattern, StateNotifierProvider usang, atau Consumer bertingkat yang tidak perlu)? Perbaiki ke pola Notifier/ConsumerWidget.
Jalankan flutter analyze dan flutter test, apakah hasil AI lolos tanpa warning?


jawaban 
1. State diubah secara immutable — YA
- StatsNotifier.retry() selalu assign AsyncValue baru: state = const AsyncLoading() lalu state = await AsyncValue.guard(...) — stats_provider.dart:41-42, tidak ada mutasi list.
- _load() mengembalikan list const baru — stats_provider.dart:56-60.
- TodoListNotifier juga immutable: [...state, Todo(...)], copyWith(...), [...state]..removeAt(index) — todo_provider.dart:16-24.
2. ref.watch hanya di build, ref.read di callback — YA
- stats_page.dart:14 watch di top-level build; stats_page.dart:33 ref.read(...).retry() di onPressed.
- todo_page.dart:11 watch di build; checkbox/hapus/dialog pakai ref.read — todo_page.dart:21-22,33-34,60-62.
- product_page pakai ref.invalidate di callback (diperbolehkan).
3. Ketiga state AsyncValue ditangani — YA
- .when(loading: → spinner, error: → pesan + tombol Coba lagi, data: → ListView) — stats_page.dart:20-48. ProductPage juga sama.
4. Tipe eksplisit & tidak duplikat — YA
- AsyncNotifierProvider<StatsNotifier, List<String>> — stats_provider.dart:66-67
- NotifierProvider<TodoListNotifier, List<Todo>> — todo_provider.dart:27-28
- AsyncNotifierProvider<ProductsNotifier, List<String>> — products_provider.dart
- Nama unik: statsProvider, todoListProvider, productsProvider.
5. Tidak pakai API Riverpod lama — YA
- Tidak ada StateProvider/StateNotifierProvider/Consumer bertingkat; semua memakai Notifier/AsyncNotifier + ConsumerWidget modern.

6. flutter analyze
Analyzing week3_todo...                                                 
No issues found! (ran in 8.5s)

flutter test 
00:06 +2: D:/college/semester 5/PeMob/244107020122-mobile-course/03-week-3-navigation-state-management/week3_todo/test/widget_test.dart: Counter increments smoke test
══╡ EXCEPTION CAUGHT BY WIDGETS LIBRARY ╞═══════════════════════════════════════════════════════════
The following StateError was thrown building TodoPage(dirty, state: _ConsumerState#7ba9b):
Bad state: No ProviderScope found

The relevant error-causing widget was:
  TodoPage
  TodoPage:file:///D:/college/semester%205/PeMob/244107020122-mobile-course/03-week-3-navigation-state-management/week3_todo/lib/main.dart:13:21

When the exception was thrown, this was the stack:
#0      ProviderScope.containerOf (package:flutter_riverpod/src/core/provider_scope.dart:105:7)
#1      ConsumerStatefulElement.container (package:flutter_riverpod/src/core/consumer.dart:374:52)
#2      ConsumerStatefulElement.container (package:flutter_riverpod/src/core/consumer.dart)
#3      ConsumerStatefulElement.watch.<anonymous closure> (package:flutter_riverpod/src/core/consumer.dart:490:27)
#4      _LinkedHashMapMixin.putIfAbsent (dart:_compact_hash:631:23)
#5      ConsumerStatefulElement.watch (package:flutter_riverpod/src/core/consumer.dart:483:14)
#6      TodoPage.build (package:week3_todo/pages/todo_page.dart:12:23)
#7      _ConsumerState.build (package:flutter_riverpod/src/core/consumer.dart:283:48)
#8      StatefulElement.build (package:flutter/src/widgets/framework.dart:5944:27)
#9      ConsumerStatefulElement.build (package:flutter_riverpod/src/core/consumer.dart:460:20)
#10     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5830:15)
#11     StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:5995:11)
#12     Element.rebuild (package:flutter/src/widgets/framework.dart:5542:7)
#13     ComponentElement._firstBuild (package:flutter/src/widgets/framework.dart:5812:5)
#14     StatefulElement._firstBuild (package:flutter/src/widgets/framework.dart:5986:11)
#15     ComponentElement.mount (package:flutter/src/widgets/framework.dart:5806:5)
#16     ConsumerStatefulElement.mount (package:flutter_riverpod/src/core/consumer.dart:389:11)
...     Normal element mounting (260 frames)
#276    Element.inflateWidget (package:flutter/src/widgets/framework.dart:4600:20)
#277    MultiChildRenderObjectElement.inflateWidget (package:flutter/src/widgets/framework.dart:7277:36)
#278    MultiChildRenderObjectElement.mount (package:flutter/src/widgets/framework.dart:7292:32)
...     Normal element mounting (473 frames)
#751    Element.inflateWidget (package:flutter/src/widgets/framework.dart:4600:20)
#752    Element.updateChild (package:flutter/src/widgets/framework.dart:4066:20)
#753    ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5854:16)
#754    Element.rebuild (package:flutter/src/widgets/framework.dart:5542:7)
#755    ProxyElement.update (package:flutter/src/widgets/framework.dart:6162:5)
#756    _InheritedNotifierElement.update (package:flutter/src/widgets/inherited_notifier.dart:108:11)
#757    Element.updateChild (package:flutter/src/widgets/framework.dart:4050:15)
#758    ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5854:16)
#759    StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:5995:11)
#760    Element.rebuild (package:flutter/src/widgets/framework.dart:5542:7)
#761    StatefulElement.update (package:flutter/src/widgets/framework.dart:6020:5)
#762    Element.updateChild (package:flutter/src/widgets/framework.dart:4050:15)
#763    ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5854:16)
#764    Element.rebuild (package:flutter/src/widgets/framework.dart:5542:7)
#765    ProxyElement.update (package:flutter/src/widgets/framework.dart:6162:5)
#766    _InheritedNotifierElement.update (package:flutter/src/widgets/inherited_notifier.dart:108:11)
#767    Element.updateChild (package:flutter/src/widgets/framework.dart:4050:15)
#768    ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5854:16)
#769    StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:5995:11)
#770    Element.rebuild (package:flutter/src/widgets/framework.dart:5542:7)
#771    StatefulElement.update (package:flutter/src/widgets/framework.dart:6020:5)
#772    Element.updateChild (package:flutter/src/widgets/framework.dart:4050:15)
#773    ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5854:16)
#774    StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:5995:11)
#775    Element.rebuild (package:flutter/src/widgets/framework.dart:5542:7)
#776    StatefulElement.update (package:flutter/src/widgets/framework.dart:6020:5)
#777    Element.updateChild (package:flutter/src/widgets/framework.dart:4050:15)
#778    ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5854:16)
#779    Element.rebuild (package:flutter/src/widgets/framework.dart:5542:7)
#780    ProxyElement.update (package:flutter/src/widgets/framework.dart:6162:5)
#781    Element.updateChild (package:flutter/src/widgets/framework.dart:4050:15)
#782    ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5854:16)
#783    StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:5995:11)
#784    Element.rebuild (package:flutter/src/widgets/framework.dart:5542:7)
#785    StatefulElement.update (package:flutter/src/widgets/framework.dart:6020:5)
#786    Element.updateChild (package:flutter/src/widgets/framework.dart:4050:15)
#787    ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5854:16)
#788    Element.rebuild (package:flutter/src/widgets/framework.dart:5542:7)
#789    ProxyElement.update (package:flutter/src/widgets/framework.dart:6162:5)
#790    Element.updateChild (package:flutter/src/widgets/framework.dart:4050:15)
#791    ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5854:16)
#792    Element.rebuild (package:flutter/src/widgets/framework.dart:5542:7)
#793    ProxyElement.update (package:flutter/src/widgets/framework.dart:6162:5)
#794    Element.updateChild (package:flutter/src/widgets/framework.dart:4050:15)
#795    _RawViewElement._updateChild (package:flutter/src/widgets/view.dart:488:16)
#796    _RawViewElement.update (package:flutter/src/widgets/view.dart:575:5)
#797    Element.updateChild (package:flutter/src/widgets/framework.dart:4050:15)
#798    ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5854:16)
#799    Element.rebuild (package:flutter/src/widgets/framework.dart:5542:7)
#800    StatelessElement.update (package:flutter/src/widgets/framework.dart:5908:5)
#801    Element.updateChild (package:flutter/src/widgets/framework.dart:4050:15)
#802    ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5854:16)
#803    StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:5995:11)
#804    Element.rebuild (package:flutter/src/widgets/framework.dart:5542:7)
#805    StatefulElement.update (package:flutter/src/widgets/framework.dart:6020:5)
#806    Element.updateChild (package:flutter/src/widgets/framework.dart:4050:15)
#807    RootElement._rebuild (package:flutter/src/widgets/binding.dart:2091:16)
#808    RootElement.update (package:flutter/src/widgets/binding.dart:2069:5)
#809    RootElement.performRebuild (package:flutter/src/widgets/binding.dart:2083:7)
#810    Element.rebuild (package:flutter/src/widgets/framework.dart:5542:7)
#811    BuildScope._tryRebuild (package:flutter/src/widgets/framework.dart:2763:15)
#812    BuildScope._flushDirtyElements (package:flutter/src/widgets/framework.dart:2820:11)
#813    BuildOwner.buildScope (package:flutter/src/widgets/framework.dart:3124:18)
#814    AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2432:19)
#815    RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#816    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#817    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#818    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#821    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#822    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#823    WidgetTester.pumpWidget.<anonymous closure> (package:flutter_test/src/widget_tester.dart:598:22)
#826    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#827    WidgetTester.pumpWidget (package:flutter_test/src/widget_tester.dart:595:27)
#828    main.<anonymous closure> (file:///D:/college/semester%205/PeMob/244107020122-mobile-course/03-week-3-navigation-state-management/week3_todo/test/widget_test.dart:16:18)
#829    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:29)
<asynchronous suspension>
#830    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 5 frames from dart:async and package:stack_trace)

════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "0": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///D:/college/semester%205/PeMob/244107020122-mobile-course/03-week-3-navigation-state-management/week3_todo/test/widget_test.dart:19:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///D:/college/semester%205/PeMob/244107020122-mobile-course/03-week-3-navigation-state-management/week3_todo/test/widget_test.dart line 19
The test description was:
  Counter increments smoke test
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following message was thrown:
Multiple exceptions (2) were detected during the running of the current test, and at least one was
unexpected.
════════════════════════════════════════════════════════════════════════════════════════════════════
00:06 +2 -1: D:/college/semester 5/PeMob/244107020122-mobile-course/03-week-3-navigation-state-management/week3_todo/test/widget_test.dart: Counter increments smoke test [E]
  Test failed. See exception logs above.
  The test description was: Counter increments smoke test
  

To run this test again: C:\Users\USER\flutter\bin\cache\dart-sdk\bin\dart.exe test D:/college/semester 5/PeMob/244107020122-mobile-course/03-week-3-navigation-state-management/week3_todo/test/widget_test.dart -p vm --plain-name "Counter increments smoke test"
00:35 +2 -2: D:/college/semester 5/PeMob/244107020122-mobile-course/03-week-3-navigation-state-management/week3_todo/test/stats_provider_test.dart: StatsNotifier gagal: exception pada build menjadi AsyncError [E]
  TimeoutException after 0:00:30.000000: Test timed out after 30 seconds. See https://pub.dev/packages/test#timeouts
  dart:isolate  _RawReceivePort._handleMessage
  
  Expected: throws <Instance of 'Exception'>
    Actual: <Instance of 'Future<List<String>>'>
     Which: threw StateError:<Bad state: The provider AsyncNotifierProvider<StatsNotifier, List<String>>#48437 was disposed during loading state, yet no value could be emitted.>
            stack package:riverpod/src/core/element.dart 341:70              ElementWithFuture.dispose
                  package:riverpod/src/core/provider_container.dart 1317:15  ProviderContainer._dispose
                  package:riverpod/src/core/provider_container.dart 1335:21  ProviderContainer.dispose
                  ===== asynchronous gap ===========================
                  dart:async                                                 _Completer.completeError
                  package:riverpod/src/core/element.dart 341:19              ElementWithFuture.dispose
                  package:riverpod/src/core/provider_container.dart 1317:15  ProviderContainer._dispose
                  package:riverpod/src/core/provider_container.dart 1335:21  ProviderContainer.dispose
                  
            which is not an instance of 'Exception'
  
  package:matcher                                    expectLater
  package:flutter_test/src/widget_tester.dart 507:8  expectLater
  test\stats_provider_test.dart 85:13                main.<fn>.<fn>
  

To run this test again: C:\Users\USER\flutter\bin\cache\dart-sdk\bin\dart.exe test D:/college/semester 5/PeMob/244107020122-mobile-course/03-week-3-navigation-state-management/week3_todo/test/stats_provider_test.dart -p vm --plain-name "StatsNotifier gagal: exception pada build menjadi AsyncError"
01:05 +2 -3: D:/college/semester 5/PeMob/244107020122-mobile-course/03-week-3-navigation-state-management/week3_todo/test/stats_provider_test.dart: StatsNotifier retry: build pertama gagal, lalu retry() berhasil [E]
  TimeoutException after 0:00:30.000000: Test timed out after 30 seconds. See https://pub.dev/packages/test#timeouts
  dart:isolate  _RawReceivePort._handleMessage
  
  Expected: throws <Instance of 'Exception'>
    Actual: <Instance of 'Future<List<String>>'>
     Which: threw StateError:<Bad state: The provider AsyncNotifierProvider<StatsNotifier, List<String>>#48437 was disposed during loading state, yet no value could be emitted.>
            stack package:riverpod/src/core/element.dart 341:70              ElementWithFuture.dispose
                  package:riverpod/src/core/provider_container.dart 1317:15  ProviderContainer._dispose
                  package:riverpod/src/core/provider_container.dart 1335:21  ProviderContainer.dispose
                  ===== asynchronous gap ===========================
                  dart:async                                                 _Completer.completeError
                  package:riverpod/src/core/element.dart 341:19              ElementWithFuture.dispose
                  package:riverpod/src/core/provider_container.dart 1317:15  ProviderContainer._dispose
                  package:riverpod/src/core/provider_container.dart 1335:21  ProviderContainer.dispose
                  
            which is not an instance of 'Exception'
  
  package:matcher                                    expectLater
  package:flutter_test/src/widget_tester.dart 507:8  expectLater
  test\stats_provider_test.dart 105:13               main.<fn>.<fn>
  

To run this test again: C:\Users\USER\flutter\bin\cache\dart-sdk\bin\dart.exe test D:/college/semester 5/PeMob/244107020122-mobile-course/03-week-3-navigation-state-management/week3_todo/test/stats_provider_test.dart -p vm --plain-name "StatsNotifier retry: build pertama gagal, lalu retry() berhasil"
01:05 +2 -3: Some tests failed.                                                                                                     
PS D:\college\semester 5\PeMob\244107020122-mobile-course\03-week-3-navigation-state-management\week3_todo> 

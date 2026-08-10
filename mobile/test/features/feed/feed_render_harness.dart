// Renders the community feed's major states from canned data through the
// FeedRepository seam — the photographs the UI pass reviews.
//
// Run one test at a time (flutter test hangs at exit in this environment):
//   flutter test test/features/feed/feed_render_harness.dart --plain-name "..."
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/core/error/failures.dart';
import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/core/theme/app_theme.dart';
import 'package:fyc_connect/features/auth/data/models/user_model.dart';
import 'package:fyc_connect/features/auth/domain/entities/user_entity.dart';
import 'package:fyc_connect/features/auth/domain/repositories/auth_repository.dart';
import 'package:fyc_connect/features/auth/domain/usecases/register_user_usecase.dart';
import 'package:fyc_connect/features/auth/domain/usecases/send_otp_usecase.dart';
import 'package:fyc_connect/features/auth/domain/usecases/verify_otp_usecase.dart';
import 'package:fyc_connect/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fyc_connect/features/auth/presentation/bloc/auth_event.dart';
import 'package:fyc_connect/features/feed/data/models/feed_models.dart';
import 'package:fyc_connect/features/feed/domain/repositories/feed_repository.dart';
import 'package:fyc_connect/features/feed/presentation/screens/feed_screen.dart';
import 'package:fyc_connect/service_locator.dart';

const _shotKey = Key('shot-boundary');

Future<void> _shoot(WidgetTester t, String name) async {
  await t.pump(const Duration(milliseconds: 400));
  final boundary = find.byKey(_shotKey).evaluate().first.renderObject!
      as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = Directory('build/ui_shots')..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  debugPrint('WROTE ${dir.path}/$name.png');
}

class _AuthRepo implements AuthRepository {
  _AuthRepo(this.user);
  final UserModel user;
  @override
  Future<Either<Failure, UserEntity>> getMe() async => Right(user);
  @override
  Future<void> logout() async {}
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class FakeFeedRepository implements FeedRepository {
  FakeFeedRepository(this.posts, {this.activity = const []});
  final List<Post> posts;
  final List<Map<String, dynamic>> activity;

  @override
  Future<List<Post>> list({
    String scope = 'all',
    String feed = 'recent',
    String? category,
    String? source,
    int limit = 20,
    int offset = 0,
  }) async =>
      offset > 0 ? const [] : posts;

  @override
  Future<List<Map<String, dynamic>>> activityFeed() async => activity;

  @override
  Future<List<String>> recentHashtags() async =>
      const ['#FYC', '#Community', '#Cricket'];

  @override
  Future<Map<String, dynamic>> toggleLike(String postId) async =>
      {'liked': true, 'like_count': 1};

  @override
  Future<Map<String, dynamic>> toggleRepost(String postId) async =>
      {'reposted': true, 'repost_count': 1};

  @override
  Future<List<PostComment>> comments(String postId) async => const [];

  @override
  Future<PostComment> addComment(String postId, String content,
          {String? idempotencyKey}) async =>
      throw UnimplementedError();

  @override
  Future<Post> create(
          {required String content,
          required List<String> imageUrls,
          String? category,
          String? location,
          bool shareToInstagram = false,
          String? idempotencyKey}) async =>
      posts.first;

  @override
  Future<void> delete(String postId) async {}
  @override
  Future<void> hide(String postId) async {}
  @override
  Future<void> report(String postId, {String? reason}) async {}
  @override
  Future<void> blockUser(String userId) async {}
  @override
  Future<String> uploadImage(String filePath) async => '/uploads/x.jpg';
}

Post _post(int i, String author, String content,
        {int likes = 0, int comments = 0, String? category, String? role}) =>
    Post(
      id: 'p$i',
      author: PostAuthor(id: 'u$i', name: author, role: role, verified: i == 1),
      content: content,
      imageUrls: const [],
      createdAt: DateTime(2026, 8, 9, 8 + i),
      likeCount: likes,
      commentCount: comments,
      likedByMe: i == 2,
      category: category,
    );

List<Post> get _posts => [
      _post(1, 'Arun Kumar',
          'இன்று மாலை 6 மணிக்கு கடற்கரை மைதானத்தில் கிரிக்கெட் பயிற்சி. அனைவரும் வாருங்கள்! 🏏',
          likes: 12, comments: 4, category: 'Sports', role: 'Admin'),
      _post(2, 'Meena R.',
          'Blood donation camp this Sunday at the community hall. We need 20 volunteers — comment below if you can help.',
          likes: 28, comments: 11, category: 'Health', role: 'Volunteer'),
      _post(3, 'Suresh K.',
          'The chess tournament bracket is out! Quarter-finals start tomorrow. #FYC #Chess',
          likes: 9, comments: 2),
    ];

Future<void> _pump(WidgetTester t, FakeFeedRepository repo) async {
  SharedPreferences.setMockInitialValues(
      // Marker AND token: a signed-in member has both. Seeding only
      // the marker is the reinstall bug the session gate now refuses.
      {'fyc_has_session': true, 'fyc_auth_token': 'test-token'});
  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorage(prefs);
  await storage.saveLang('en');
  final user = UserModel(
      id: 'u1',
      phoneNumber: '+919000000001',
      role: 'ADMIN',
      isVerified: true,
      preferredLanguage: 'en',
      fullNameEn: 'Arun Kumar');
  await storage.saveCachedUser(user.toJson());
  if (sl.isRegistered<LocalStorage>()) sl.unregister<LocalStorage>();
  sl.registerSingleton<LocalStorage>(storage);

  final authRepo = _AuthRepo(user);
  final auth = AuthBloc(
    sendOtp: SendOtpUseCase(authRepo),
    verifyOtp: VerifyOtpUseCase(authRepo),
    registerUser: RegisterUserUseCase(authRepo),
    repository: authRepo,
    storage: storage,
  )..add(const AuthCheckRequested());

  await t.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(BlocProvider.value(
    value: auth,
    child: MaterialApp(
      theme: AppTheme.lightFor('en'),
      builder: (_, child) => RepaintBoundary(key: _shotKey, child: child),
      home: FeedScreen(repo: repo),
    ),
  ));
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 80));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final (family, path) in [
      ('Plus Jakarta Sans', 'assets/fonts/PlusJakartaSans-400.ttf'),
      ('Plus Jakarta Sans', 'assets/fonts/PlusJakartaSans-700.ttf'),
      ('Noto Sans Tamil', 'assets/fonts/NotoSansTamil-400.ttf'),
    ]) {
      final f = File(path);
      if (!f.existsSync()) continue;
      final loader = FontLoader(family)
        ..addFont(f.readAsBytes().then((b) => b.buffer.asByteData()));
      await loader.load();
    }
    final icons = File(
        '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(icons.readAsBytes().then((b) => b.buffer.asByteData()));
      await loader.load();
    }
  });

  testWidgets('60 · the feed with posts', (t) async {
    await _pump(t, FakeFeedRepository(_posts));
    await _shoot(t, '60_feed_posts');
  });

  testWidgets('61 · the empty feed', (t) async {
    await _pump(t, FakeFeedRepository(const []));
    await _shoot(t, '61_feed_empty');
  });
}

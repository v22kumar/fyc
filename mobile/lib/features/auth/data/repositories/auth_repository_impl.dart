import 'package:dartz/dartz.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/storage/local_storage.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final LocalStorage _storage;

  AuthRepositoryImpl(this._remote, this._storage);

  @override
  Future<Either<Failure, String>> sendOtp({
    required String organizationId,
    required String phoneNumber,
  }) async {
    try {
      final verificationId = await _remote.sendOtp(
        organizationId: organizationId,
        phoneNumber: phoneNumber,
      );
      return Right(verificationId);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, UserEntity>> verifyOtp({
    required String verificationId,
    required String otpCode,
  }) async {
    try {
      final token = await _remote.verifyOtp(
        verificationId: verificationId,
        otpCode: otpCode,
      );
      await _storage.saveToken(token.accessToken);
      return Right(token.user);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, UserEntity>> registerUser({
    required String organizationId,
    required String phoneNumber,
    required String role,
    required String fullNameTa,
    required String fullNameEn,
    required String preferredLanguage,
  }) async {
    try {
      final token = await _remote.registerUser(
        organizationId: organizationId,
        phoneNumber: phoneNumber,
        role: role,
        fullNameTa: fullNameTa,
        fullNameEn: fullNameEn,
        preferredLanguage: preferredLanguage,
      );
      await _storage.saveToken(token.accessToken);
      return Right(token.user);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, UserEntity>> loginWithPassword({
    required String organizationId,
    required String username,
    required String password,
  }) async {
    // Dev bypass — only active when built with --dart-define=DEV_AUTH_BYPASS=true
    if (ApiConstants.devBypassAuth && username.trim() == 'admin' && password == 'password123') {
      const mockUser = UserEntity(
        id: 'dev-admin-id',
        phoneNumber: '+919999999999',
        email: 'admin@friendsyouthclub.com',
        role: 'SUPER_ADMIN',
        isVerified: true,
        preferredLanguage: 'en',
        fullNameEn: 'FYC Admin',
        fullNameTa: 'நிர்வாகி',
        isProfileComplete: true,
      );
      await _storage.saveToken('dev_bypass_token');
      return const Right(mockUser);
    }

    try {
      final token = await _remote.loginWithPassword(
        organizationId: organizationId,
        username: username,
        password: password,
      );
      await _storage.saveToken(token.accessToken);
      return Right(token.user);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signInWithGoogle({
    required String organizationId,
  }) async {
    try {
      final token = await _remote.signInWithGoogle(organizationId: organizationId);
      await _storage.saveToken(token.accessToken);
      return Right(token.user);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, UserEntity>> getMe() async {
    try {
      // Dev bypass token — paired with the DEV_AUTH_BYPASS admin login
      final token = await _storage.getToken();
      if (ApiConstants.devBypassAuth && token == 'dev_bypass_token') {
        return const Right(UserEntity(
          id: 'dev-admin-id',
          phoneNumber: '+919999999999',
          email: 'admin@friendsyouthclub.com',
          role: 'SUPER_ADMIN',
          isVerified: true,
          preferredLanguage: 'en',
          fullNameEn: 'FYC Admin',
          fullNameTa: 'நிர்வாகி',
          isProfileComplete: true,
        ));
      }
      final user = await _remote.getMe();
      return Right(user);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<void> logout() async {
    await _remote.signOutGoogle(); // clear cached Google session
    await _storage.clearToken();
  }
}

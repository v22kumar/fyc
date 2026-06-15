import 'package:dartz/dartz.dart';
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
      return Left(ServerFailure(e.toString()));
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
      return Left(ServerFailure(e.toString()));
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
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> loginWithPassword({
    required String organizationId,
    required String username,
    required String password,
  }) async {
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
      return Left(ServerFailure(e.toString()));
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
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> getMe() async {
    try {
      final user = await _remote.getMe();
      return Right(user);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<void> logout() async {
    await _storage.clearToken();
  }
}

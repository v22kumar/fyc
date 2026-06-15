import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class VerifyOtpUseCase {
  final AuthRepository repository;
  VerifyOtpUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call({
    required String verificationId,
    required String otpCode,
  }) {
    if (otpCode.length != 6) {
      return Future.value(
        const Left(ValidationFailure('OTP must be 6 digits')),
      );
    }
    return repository.verifyOtp(
      verificationId: verificationId,
      otpCode: otpCode,
    );
  }
}

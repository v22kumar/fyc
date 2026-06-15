import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

class SendOtpUseCase {
  final AuthRepository repository;
  SendOtpUseCase(this.repository);

  Future<Either<Failure, String>> call({
    required String organizationId,
    required String phoneNumber,
  }) {
    if (phoneNumber.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Phone number is required')));
    }
    return repository.sendOtp(
      organizationId: organizationId,
      phoneNumber: phoneNumber.trim(),
    );
  }
}

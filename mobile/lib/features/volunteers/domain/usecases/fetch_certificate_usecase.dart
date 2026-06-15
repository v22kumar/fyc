import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/certificate_repository.dart';

class FetchCertificateUseCase {
  final CertificateRepository repository;
  FetchCertificateUseCase(this.repository);

  Future<Either<Failure, Uint8List>> call() {
    return repository.fetchCertificateBytes();
  }
}

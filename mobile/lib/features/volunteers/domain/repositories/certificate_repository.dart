import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';

abstract class CertificateRepository {
  Future<Either<Failure, Uint8List>> fetchCertificateBytes();
}

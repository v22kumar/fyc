import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/repositories/certificate_repository.dart';
import '../datasources/certificate_datasource.dart';

class CertificateRepositoryImpl implements CertificateRepository {
  final CertificateDataSource _remote;
  CertificateRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, Uint8List>> fetchCertificateBytes() async {
    try {
      final bytes = await _remote.fetchCertificateBytes();
      return Right(bytes);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}

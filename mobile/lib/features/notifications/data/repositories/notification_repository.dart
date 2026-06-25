import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/notification_entity.dart';
import '../datasources/notification_remote_data_source.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final NotificationRemoteDataSource remoteDataSource;

  NotificationRepository(this.remoteDataSource);

  Future<Either<Failure, List<NotificationEntity>>> getNotifications() async {
    try {
      final notifications = await remoteDataSource.getNotifications();
      return Right(notifications);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, NotificationEntity>> markAsRead(String id) async {
    try {
      final notification = await remoteDataSource.markAsRead(id);
      return Right(notification);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> markAllAsRead() async {
    try {
      await remoteDataSource.markAllAsRead();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, NotificationPreferenceEntity>> getPreferences() async {
    try {
      final prefs = await remoteDataSource.getPreferences();
      return Right(prefs);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, NotificationPreferenceEntity>> updatePreferences(NotificationPreferenceEntity prefs) async {
    try {
      final model = NotificationPreferenceModel(
        pushEnabled: prefs.pushEnabled,
        whatsappEnabled: prefs.whatsappEnabled,
        smsEnabled: prefs.smsEnabled,
        emailEnabled: prefs.emailEnabled,
        newsEnabled: prefs.newsEnabled,
        sportsEnabled: prefs.sportsEnabled,
        communityEnabled: prefs.communityEnabled,
        eventsEnabled: prefs.eventsEnabled,
      );
      final updatedPrefs = await remoteDataSource.updatePreferences(model);
      return Right(updatedPrefs);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}

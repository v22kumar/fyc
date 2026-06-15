import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/network/api_client.dart';
import 'core/storage/local_storage.dart';

// Auth
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/send_otp_usecase.dart';
import 'features/auth/domain/usecases/verify_otp_usecase.dart';
import 'features/auth/domain/usecases/register_user_usecase.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

// Blood donation
import 'features/blood_donation/data/datasources/blood_donor_datasource.dart';
import 'features/blood_donation/data/repositories/blood_donor_repository_impl.dart';
import 'features/blood_donation/domain/repositories/blood_donor_repository.dart';
import 'features/blood_donation/domain/usecases/search_donors_usecase.dart';
import 'features/blood_donation/domain/usecases/register_donor_usecase.dart';
import 'features/blood_donation/presentation/bloc/blood_donor_bloc.dart';

// Events
import 'features/events/data/datasources/event_datasource.dart';
import 'features/events/data/repositories/event_repository_impl.dart';
import 'features/events/domain/repositories/event_repository.dart';
import 'features/events/domain/usecases/fetch_events_usecase.dart';
import 'features/events/presentation/bloc/event_bloc.dart';

// Issues
import 'features/issues/data/datasources/issue_datasource.dart';
import 'features/issues/data/repositories/issue_repository_impl.dart';
import 'features/issues/domain/repositories/issue_repository.dart';
import 'features/issues/domain/usecases/submit_issue_usecase.dart';
import 'features/issues/presentation/bloc/issue_bloc.dart';

// Membership
import 'features/membership/data/datasources/membership_datasource.dart';
import 'features/membership/data/repositories/membership_repository_impl.dart';
import 'features/membership/domain/repositories/membership_repository.dart';
import 'features/membership/domain/usecases/get_my_card_usecase.dart';
import 'features/membership/presentation/bloc/membership_bloc.dart';

final sl = GetIt.instance;

Future<void> initServiceLocator() async {
  // Core
  final prefs = await SharedPreferences.getInstance();
  final localStorage = LocalStorage(prefs);
  sl.registerSingleton<LocalStorage>(localStorage);

  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(sl<LocalStorage>()),
  );

  // ── Auth ──────────────────────────────────────────────────────────────────
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl<AuthRemoteDataSource>(), sl<LocalStorage>()),
  );
  sl.registerLazySingleton(() => SendOtpUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => VerifyOtpUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => RegisterUserUseCase(sl<AuthRepository>()));
  // Singleton so GoRouter can read its state for redirect guard
  sl.registerSingleton<AuthBloc>(
    AuthBloc(
      sendOtp: sl<SendOtpUseCase>(),
      verifyOtp: sl<VerifyOtpUseCase>(),
      registerUser: sl<RegisterUserUseCase>(),
      repository: sl<AuthRepository>(),
      storage: sl<LocalStorage>(),
    ),
  );

  // ── Blood donation ────────────────────────────────────────────────────────
  sl.registerLazySingleton<BloodDonorDataSource>(
    () => BloodDonorDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<BloodDonorRepository>(
    () => BloodDonorRepositoryImpl(sl<BloodDonorDataSource>()),
  );
  sl.registerLazySingleton(() => SearchDonorsUseCase(sl<BloodDonorRepository>()));
  sl.registerLazySingleton(() => RegisterDonorUseCase(sl<BloodDonorRepository>()));
  sl.registerFactory<BloodDonorBloc>(
    () => BloodDonorBloc(
      searchDonors: sl<SearchDonorsUseCase>(),
      registerDonor: sl<RegisterDonorUseCase>(),
      repository: sl<BloodDonorRepository>(),
    ),
  );

  // ── Events ────────────────────────────────────────────────────────────────
  sl.registerLazySingleton<EventDataSource>(
    () => EventDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<EventRepository>(
    () => EventRepositoryImpl(sl<EventDataSource>()),
  );
  sl.registerLazySingleton(() => FetchEventsUseCase(sl<EventRepository>()));
  sl.registerFactory<EventBloc>(
    () => EventBloc(
      fetchEvents: sl<FetchEventsUseCase>(),
      repository: sl<EventRepository>(),
    ),
  );

  // ── Issues ────────────────────────────────────────────────────────────────
  sl.registerLazySingleton<IssueDataSource>(
    () => IssueDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<IssueRepository>(
    () => IssueRepositoryImpl(sl<IssueDataSource>()),
  );
  sl.registerLazySingleton(() => SubmitIssueUseCase(sl<IssueRepository>()));
  sl.registerFactory<IssueBloc>(
    () => IssueBloc(submitIssue: sl<SubmitIssueUseCase>()),
  );

  // ── Membership ────────────────────────────────────────────────────────────
  sl.registerLazySingleton<MembershipDataSource>(
    () => MembershipDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<MembershipRepository>(
    () => MembershipRepositoryImpl(sl<MembershipDataSource>()),
  );
  sl.registerLazySingleton(() => GetMyCardUseCase(sl<MembershipRepository>()));
  sl.registerFactory<MembershipBloc>(
    () => MembershipBloc(getMyCard: sl<GetMyCardUseCase>()),
  );
}

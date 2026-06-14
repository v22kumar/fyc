import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/network/api_client.dart';
import 'core/storage/local_storage.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/send_otp_usecase.dart';
import 'features/auth/domain/usecases/verify_otp_usecase.dart';
import 'features/auth/domain/usecases/register_user_usecase.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/blood_donation/data/datasources/blood_donor_datasource.dart';
import 'features/blood_donation/data/repositories/blood_donor_repository_impl.dart';
import 'features/blood_donation/domain/repositories/blood_donor_repository.dart';
import 'features/blood_donation/domain/usecases/search_donors_usecase.dart';
import 'features/blood_donation/domain/usecases/register_donor_usecase.dart';
import 'features/blood_donation/presentation/bloc/blood_donor_bloc.dart';

final sl = GetIt.instance;

Future<void> initServiceLocator() async {
  // Core
  final prefs = await SharedPreferences.getInstance();
  final localStorage = LocalStorage(prefs);
  sl.registerSingleton<LocalStorage>(localStorage);

  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(sl<LocalStorage>()),
  );

  // Auth — data
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl<AuthRemoteDataSource>(), sl<LocalStorage>()),
  );

  // Auth — use cases
  sl.registerLazySingleton(() => SendOtpUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => VerifyOtpUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => RegisterUserUseCase(sl<AuthRepository>()));

  // Auth — BLoC (singleton so router can access state)
  sl.registerSingleton<AuthBloc>(
    AuthBloc(
      sendOtp: sl<SendOtpUseCase>(),
      verifyOtp: sl<VerifyOtpUseCase>(),
      registerUser: sl<RegisterUserUseCase>(),
      repository: sl<AuthRepository>(),
      storage: sl<LocalStorage>(),
    ),
  );

  // Blood donation — data
  sl.registerLazySingleton<BloodDonorDataSource>(
    () => BloodDonorDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<BloodDonorRepository>(
    () => BloodDonorRepositoryImpl(sl<BloodDonorDataSource>()),
  );

  // Blood donation — use cases
  sl.registerLazySingleton(() => SearchDonorsUseCase(sl<BloodDonorRepository>()));
  sl.registerLazySingleton(() => RegisterDonorUseCase(sl<BloodDonorRepository>()));

  // Blood donation — BLoC (factory so each screen gets a fresh instance)
  sl.registerFactory<BloodDonorBloc>(
    () => BloodDonorBloc(
      searchDonors: sl<SearchDonorsUseCase>(),
      registerDonor: sl<RegisterDonorUseCase>(),
      repository: sl<BloodDonorRepository>(),
    ),
  );
}

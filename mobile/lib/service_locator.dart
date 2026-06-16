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

// Sports
import 'features/sports/data/datasources/sports_datasource.dart';
import 'features/sports/data/repositories/sports_repository_impl.dart';
import 'features/sports/domain/repositories/sports_repository.dart';
import 'features/sports/domain/usecases/fetch_tournaments_usecase.dart';
import 'features/sports/domain/usecases/submit_challenge_usecase.dart';
import 'features/sports/presentation/bloc/sports_bloc.dart';

// Green FYC
import 'features/green_fyc/data/datasources/green_datasource.dart';
import 'features/green_fyc/data/repositories/green_repository_impl.dart';
import 'features/green_fyc/domain/repositories/green_repository.dart';
import 'features/green_fyc/domain/usecases/fetch_drives_usecase.dart';
import 'features/green_fyc/domain/usecases/register_tree_usecase.dart';
import 'features/green_fyc/presentation/bloc/green_bloc.dart';

// Directory
import 'features/directory/data/datasources/contact_datasource.dart';
import 'features/directory/data/repositories/contact_repository_impl.dart';
import 'features/directory/domain/repositories/contact_repository.dart';
import 'features/directory/domain/usecases/fetch_contacts_usecase.dart';
import 'features/directory/presentation/bloc/directory_bloc.dart';

// Announcements
import 'features/announcements/data/datasources/announcement_datasource.dart';
import 'features/announcements/data/repositories/announcement_repository_impl.dart';
import 'features/announcements/domain/repositories/announcement_repository.dart';
import 'features/announcements/domain/usecases/fetch_announcements_usecase.dart';
import 'features/announcements/presentation/bloc/announcement_bloc.dart';

// Gallery
import 'features/gallery/data/datasources/gallery_datasource.dart';
import 'features/gallery/data/repositories/gallery_repository_impl.dart';
import 'features/gallery/domain/repositories/gallery_repository.dart';
import 'features/gallery/domain/usecases/fetch_photos_usecase.dart';
import 'features/gallery/presentation/bloc/gallery_bloc.dart';

// Issues — tracking/list
import 'features/issues/data/datasources/issue_list_datasource.dart';
import 'features/issues/data/repositories/issue_list_repository_impl.dart';
import 'features/issues/domain/repositories/issue_list_repository.dart';
import 'features/issues/domain/usecases/fetch_issues_usecase.dart';
import 'features/issues/presentation/bloc/issue_list_bloc.dart';

// Volunteer certificate
import 'features/volunteers/data/datasources/certificate_datasource.dart';
import 'features/volunteers/data/repositories/certificate_repository_impl.dart';
import 'features/volunteers/domain/repositories/certificate_repository.dart';
import 'features/volunteers/domain/usecases/fetch_certificate_usecase.dart';
import 'features/volunteers/presentation/bloc/volunteer_cert_bloc.dart';

// Community directory
import 'features/community/data/datasources/community_datasource.dart';
import 'features/community/data/repositories/community_repository_impl.dart';
import 'features/community/domain/repositories/community_repository.dart';
import 'features/community/domain/usecases/fetch_profiles_usecase.dart';
import 'features/community/presentation/bloc/community_bloc.dart';

// Thirukkural (daily couplet)
import 'features/thirukkural/data/datasources/thirukkural_datasource.dart';

// News (Tamil headlines)
import 'features/news/data/datasources/news_datasource.dart';

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

  // ── Sports ────────────────────────────────────────────────────────────────
  sl.registerLazySingleton<SportsDataSource>(
    () => SportsDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<SportsRepository>(
    () => SportsRepositoryImpl(sl<SportsDataSource>()),
  );
  sl.registerLazySingleton(() => FetchTournamentsUseCase(sl<SportsRepository>()));
  sl.registerLazySingleton(() => SubmitChallengeUseCase(sl<SportsRepository>()));
  sl.registerFactory<SportsBloc>(
    () => SportsBloc(
      fetchTournaments: sl<FetchTournamentsUseCase>(),
      submitChallenge: sl<SubmitChallengeUseCase>(),
      repository: sl<SportsRepository>(),
    ),
  );

  // ── Green FYC ─────────────────────────────────────────────────────────────
  sl.registerLazySingleton<GreenDataSource>(
    () => GreenDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<GreenRepository>(
    () => GreenRepositoryImpl(sl<GreenDataSource>()),
  );
  sl.registerLazySingleton(() => FetchDrivesUseCase(sl<GreenRepository>()));
  sl.registerLazySingleton(() => RegisterTreeUseCase(sl<GreenRepository>()));
  sl.registerFactory<GreenBloc>(
    () => GreenBloc(
      fetchDrives: sl<FetchDrivesUseCase>(),
      registerTree: sl<RegisterTreeUseCase>(),
      repository: sl<GreenRepository>(),
    ),
  );

  // ── Directory ─────────────────────────────────────────────────────────────
  sl.registerLazySingleton<ContactDataSource>(
    () => ContactDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<ContactRepository>(
    () => ContactRepositoryImpl(sl<ContactDataSource>()),
  );
  sl.registerLazySingleton(() => FetchContactsUseCase(sl<ContactRepository>()));
  sl.registerFactory<DirectoryBloc>(
    () => DirectoryBloc(fetchContacts: sl<FetchContactsUseCase>()),
  );

  // Announcements
  sl.registerLazySingleton<AnnouncementDataSource>(
    () => AnnouncementDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<AnnouncementRepository>(
    () => AnnouncementRepositoryImpl(sl<AnnouncementDataSource>()),
  );
  sl.registerLazySingleton(
    () => FetchAnnouncementsUseCase(sl<AnnouncementRepository>()),
  );
  sl.registerFactory<AnnouncementBloc>(
    () => AnnouncementBloc(fetchAnnouncements: sl<FetchAnnouncementsUseCase>()),
  );

  // ── Gallery ───────────────────────────────────────────────────────────────
  sl.registerLazySingleton<GalleryDataSource>(
    () => GalleryDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<GalleryRepository>(
    () => GalleryRepositoryImpl(sl<GalleryDataSource>()),
  );
  sl.registerLazySingleton(() => FetchPhotosUseCase(sl<GalleryRepository>()));
  sl.registerFactory<GalleryBloc>(
    () => GalleryBloc(
      fetchPhotos: sl<FetchPhotosUseCase>(),
      repository: sl<GalleryRepository>(),
    ),
  );

  // Issue tracking / list
  sl.registerLazySingleton<IssueListDataSource>(
    () => IssueListDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<IssueListRepository>(
    () => IssueListRepositoryImpl(sl<IssueListDataSource>()),
  );
  sl.registerLazySingleton(() => FetchIssuesUseCase(sl<IssueListRepository>()));
  sl.registerFactory<IssueListBloc>(
    () => IssueListBloc(fetchIssues: sl<FetchIssuesUseCase>()),
  );

  // Volunteer certificate
  sl.registerLazySingleton<CertificateDataSource>(
    () => CertificateDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<CertificateRepository>(
    () => CertificateRepositoryImpl(sl<CertificateDataSource>()),
  );
  sl.registerLazySingleton(
    () => FetchCertificateUseCase(sl<CertificateRepository>()),
  );
  sl.registerFactory<VolunteerCertBloc>(
    () => VolunteerCertBloc(fetchCertificate: sl<FetchCertificateUseCase>()),
  );

  // Community directory
  sl.registerLazySingleton<CommunityDataSource>(
    () => CommunityDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<CommunityRepository>(
    () => CommunityRepositoryImpl(sl<CommunityDataSource>()),
  );
  sl.registerLazySingleton(() => FetchProfilesUseCase(sl<CommunityRepository>()));
  sl.registerFactory<CommunityBloc>(
    () => CommunityBloc(fetchProfiles: sl<FetchProfilesUseCase>()),
  );

  // Thirukkural (daily couplet)
  sl.registerLazySingleton<ThirukkuralDataSource>(
    () => ThirukkuralDataSourceImpl(sl<ApiClient>()),
  );

  // News (Tamil headlines)
  sl.registerLazySingleton<NewsDataSource>(
    () => NewsDataSourceImpl(sl<ApiClient>()),
  );
}

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/feed_item_entity.dart';
import '../../domain/usecases/fetch_community_feed_usecase.dart';

// Events
abstract class CommunityFeedEvent extends Equatable {
  const CommunityFeedEvent();
  @override
  List<Object?> get props => [];
}

class CommunityFeedFetchRequested extends CommunityFeedEvent {
  const CommunityFeedFetchRequested();
}

// States
abstract class CommunityFeedState extends Equatable {
  const CommunityFeedState();
  @override
  List<Object?> get props => [];
}

class CommunityFeedInitial extends CommunityFeedState {}

class CommunityFeedLoading extends CommunityFeedState {}

class CommunityFeedLoaded extends CommunityFeedState {
  final List<CommunityFeedItemEntity> feed;
  const CommunityFeedLoaded(this.feed);
  @override
  List<Object?> get props => [feed];
}

class CommunityFeedFailure extends CommunityFeedState {
  final String message;
  const CommunityFeedFailure(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class CommunityFeedBloc extends Bloc<CommunityFeedEvent, CommunityFeedState> {
  final FetchCommunityFeedUseCase _fetchFeed;

  CommunityFeedBloc({required FetchCommunityFeedUseCase fetchFeed})
      : _fetchFeed = fetchFeed,
        super(CommunityFeedInitial()) {
    on<CommunityFeedFetchRequested>(_onFetch);
  }

  Future<void> _onFetch(
    CommunityFeedFetchRequested event,
    Emitter<CommunityFeedState> emit,
  ) async {
    emit(CommunityFeedLoading());
    final result = await _fetchFeed();
    result.fold(
      (f) => emit(CommunityFeedFailure(f.message)),
      (feed) => emit(CommunityFeedLoaded(feed)),
    );
  }
}

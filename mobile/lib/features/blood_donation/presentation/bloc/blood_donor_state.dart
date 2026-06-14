import 'package:equatable/equatable.dart';
import '../../domain/entities/blood_donor_entity.dart';

abstract class BloodDonorState extends Equatable {
  const BloodDonorState();
  @override
  List<Object?> get props => [];
}

class BloodDonorInitial extends BloodDonorState {
  const BloodDonorInitial();
}

class BloodDonorLoading extends BloodDonorState {
  const BloodDonorLoading();
}

class BloodDonorSearchSuccess extends BloodDonorState {
  final List<BloodDonorEntity> donors;
  final String? activeFilter;

  const BloodDonorSearchSuccess({required this.donors, this.activeFilter});

  @override
  List<Object?> get props => [donors, activeFilter];
}

class BloodDonorRegistered extends BloodDonorState {
  final BloodDonorEntity donor;
  const BloodDonorRegistered(this.donor);

  @override
  List<Object?> get props => [donor];
}

class BloodDonorContactRevealed extends BloodDonorState {
  final String phoneNumber;
  final String whatsappLink;

  const BloodDonorContactRevealed({
    required this.phoneNumber,
    required this.whatsappLink,
  });

  @override
  List<Object?> get props => [phoneNumber, whatsappLink];
}

class BloodDonorFailure extends BloodDonorState {
  final String message;
  const BloodDonorFailure(this.message);

  @override
  List<Object?> get props => [message];
}

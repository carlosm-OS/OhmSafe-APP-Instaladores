import '../error/failures.dart';

abstract class Result<T> {
  const Result();

  bool get isSuccess;
  bool get isFailure;

  T get successValue;
  Failure get failureValue;

  void fold(void Function(T value) onSuccess, void Function(Failure failure) onFailure);
}

class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);

  @override
  bool get isSuccess => true;
  @override
  bool get isFailure => false;

  @override
  T get successValue => value;
  @override
  Failure get failureValue => throw StateError("No failure value present in Success");

  @override
  void fold(void Function(T value) onSuccess, void Function(Failure failure) onFailure) {
    onSuccess(value);
  }
}

class FailureResult<T> extends Result<T> {
  final Failure failure;
  const FailureResult(this.failure);

  @override
  bool get isSuccess => false;
  @override
  bool get isFailure => true;

  @override
  T get successValue => throw StateError("No success value present in Failure");
  @override
  Failure get failureValue => failure;

  @override
  void fold(void Function(T value) onSuccess, void Function(Failure failure) onFailure) {
    onFailure(failure);
  }
}

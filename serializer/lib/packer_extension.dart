import 'package:fpdart/fpdart.dart';
import 'package:messagepack/messagepack.dart';

extension SerializerExtension on Unpacker {
  Option<String> toOptionString() => Option.tryCatch(() => unpackString()).flatMapNullable((e) => e);
  Option<int> toOptionInt() => Option.tryCatch(() => unpackInt()).flatMapNullable((e) => e);
}
//===--- Atomic.h - Utilities for atomic operations. ------------*- C++ -*-===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// Utilities for atomic operations, to use with std::atomic.
//
//===----------------------------------------------------------------------===//

#ifndef SWIFT_RUNTIME_ATOMIC_H
#define SWIFT_RUNTIME_ATOMIC_H

#include "swift/Runtime/Config.h"
#include <assert.h>
#include <atomic>

// FIXME: Workaround for rdar://problem/18889711. 'Consume' does not require
// a barrier on ARM64, but LLVM doesn't know that. Although 'relaxed'
// is formally UB by C++11 language rules, we should be OK because neither
// the processor model nor the optimizer can realistically reorder our uses
// of 'consume'.
#if defined(__arm__) || defined(_M_ARM) || defined(__arm64__) || defined(__aarch64__) || defined(_M_ARM64)
#  define SWIFT_MEMORY_ORDER_CONSUME (std::memory_order_relaxed)
#else
#  define SWIFT_MEMORY_ORDER_CONSUME (std::memory_order_consume)
#endif

#if defined(_M_ARM) || defined(__arm__) || defined(__aarch64__)
#define SWIFT_HAS_MSVC_ARM_ATOMICS 1
#else
#define SWIFT_HAS_MSVC_ARM_ATOMICS 0
#endif

namespace swift {
namespace impl {

/// The default implementation for swift::atomic<T>, which just wraps
/// std::atomic with minor differences.
///
/// TODO: should we make this use non-atomic operations when the runtime
/// is single-threaded?
template <class Value, size_t Size = sizeof(Value)>
class alignas(Size) atomic_impl {
  std::atomic<Value> value;
public:
  constexpr atomic_impl(Value value) : value(value) {}

  /// Force clients to always pass an order.
  Value load(std::memory_order order) {
    return value.load(order);
  }

  /// Force clients to always pass an order.
  bool compare_exchange_weak(Value &oldValue, Value newValue,
                             std::memory_order successOrder,
                             std::memory_order failureOrder) {
    return value.compare_exchange_weak(oldValue, newValue, successOrder,
                                       failureOrder);
  }
};

#if defined(_WIN64)
#include <intrin.h>

/// MSVC's std::atomic uses an inline spin lock for 16-byte atomics,
/// which is not only unnecessarily inefficient but also doubles the size
/// of the atomic object.  We don't care about supporting ancient
/// AMD processors that lack cmpxchg16b, so we just use the intrinsic.
template <class Value>
class alignas(2 * sizeof(void*)) atomic_impl<Value, 2 * sizeof(void*)> {
  volatile Value atomicValue;
public:
  constexpr atomic_impl(Value initialValue) : atomicValue(initialValue) {}

  atomic_impl(const atomic_impl &) = delete;
  atomic_impl &operator=(const atomic_impl &) = delete;

  Value load(std::memory_order order) {
    assert(order == std::memory_order_relaxed ||
           order == std::memory_order_acquire ||
           order == std::memory_order_consume);
    // Aligned SSE loads are atomic on every known processor, but
    // the only 16-byte access that's architecturally guaranteed to be
    // atomic is lock cmpxchg16b, so we do that with identical comparison
    // and new values purely for the side-effect of updating the old value.
    __int64 resultArray[2] = {};
#if SWIFT_HAS_MSVC_ARM_ATOMICS
    if (order != std::memory_order_acquire) {
      (void) _InterlockedCompareExchange128_nf(
                            reinterpret_cast<volatile __int64*>(&atomicValue),
                            0, 0, resultArray);
    } else {
#endif
      (void) _InterlockedCompareExchange128(
                            reinterpret_cast<volatile __int64*>(&atomicValue),
                            0, 0, resultArray);
#if SWIFT_HAS_MSVC_ARM_ATOMICS
    }
#endif
    return reinterpret_cast<Value &>(resultArray);
  }

  bool compare_exchange_weak(Value &oldValue, Value newValue,
                             std::memory_order successOrder,
                             std::memory_order failureOrder) {
    assert(failureOrder == std::memory_order_relaxed ||
           failureOrder == std::memory_order_acquire ||
           failureOrder == std::memory_order_consume);
    assert(successOrder == std::memory_order_relaxed ||
           successOrder == std::memory_order_release);
#if SWIFT_HAS_MSVC_ARM_ATOMICS
    if (successOrder == std::memory_order_relaxed &&
        failureOrder != std::memory_order_acquire) {
      return _InterlockedCompareExchange128_nf(
                            reinterpret_cast<volatile __int64*>(&atomicValue),
                            reinterpret_cast<const __int64*>(&newValue)[1],
                            reinterpret_cast<const __int64*>(&newValue)[0],
                            reinterpret_cast<__int64*>(&oldValue));
    } else if (successOrder == std::memory_order_relaxed) {
      return _InterlockedCompareExchange128_acq(
                            reinterpret_cast<volatile __int64*>(&atomicValue),
                            reinterpret_cast<const __int64*>(&newValue)[1],
                            reinterpret_cast<const __int64*>(&newValue)[0],
                            reinterpret_cast<__int64*>(&oldValue));
    } else if (failureOrder != std::memory_order_acquire) {
      return _InterlockedCompareExchange128_rel(
                            reinterpret_cast<volatile __int64*>(&atomicValue),
                            reinterpret_cast<const __int64*>(&newValue)[1],
                            reinterpret_cast<const __int64*>(&newValue)[0],
                            reinterpret_cast<__int64*>(&oldValue));
    } else {
#endif
      return _InterlockedCompareExchange128(
                            reinterpret_cast<volatile __int64*>(&atomicValue),
                            reinterpret_cast<const __int64*>(&newValue)[1],
                            reinterpret_cast<const __int64*>(&newValue)[0],
                            reinterpret_cast<__int64*>(&oldValue));
#if SWIFT_HAS_MSVC_ARM_ATOMICS
    }
#endif
  }
};

#endif

} // end namespace swift::impl

/// A simple wrapper for std::atomic that provides the most important
/// interfaces and fixes the API bug where all of the orderings dafault
/// to sequentially-consistent.
///
/// It also sometimes uses a different implementation in cases where
/// std::atomic has made unfortunate choices; our uses of this broadly
/// don't have the ABI-compatibility issues that std::atomic faces.
template <class T>
class atomic : public impl::atomic_impl<T> {
public:
  atomic(T value) : impl::atomic_impl<T>(value) {}
};

} // end namespace swift

#endif
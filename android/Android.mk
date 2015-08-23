#   honggfuzz - Android makefile
#   -----------------------------------------
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

LOCAL_PATH := $(abspath $(call my-dir)/..)

# Enable Linux ptrace() instead of POSIX signal interface by default 
ANDROID_WITH_PTRACE ?= true

ifeq ($(ANDROID_WITH_PTRACE),true)
  ifeq ($(APP_ABI),$(filter $(APP_ABI),armeabi armeabi-v7a))
    ARCH_ABI := arm
    UNW_ARCH := arm
  else ifeq ($(APP_ABI),$(filter $(APP_ABI),x86))
    ARCH_ABI := x86
    UNW_ARCH := x86
  else ifeq ($(APP_ABI),$(filter $(APP_ABI),arm64-v8a))
    ARCH_ABI := arm64
    UNW_ARCH := aarch64
  else ifeq ($(APP_ABI),$(filter $(APP_ABI),x86_64))
    ARCH_ABI := x86_64
    UNW_ARCH := x86_64
    $(error $(APP_ABI) Android not supported with ptrace API (issues with libunwind))
  else
    $(error Unsuported / Unknown APP_API '$(APP_ABI)')
  endif

  # Upstream libunwind compiled from sources with Android NDK toolchain
  LIBUNWIND_A := third_party/android/libunwind/$(ARCH_ABI)/libunwind-$(UNW_ARCH).a
  ifeq ("$(wildcard $(LIBUNWIND_A))","")
    $(error libunwind-$(UNW_ARCH). is missing. Please execute \
            'third_party/android/scripts/compile-libunwind.sh third_party/android/libunwind $(ARCH_ABI)')
  endif

  include $(CLEAR_VARS)
  LOCAL_MODULE := libunwind
  LOCAL_SRC_FILES := third_party/android/libunwind/$(ARCH_ABI)/libunwind.a
  LOCAL_EXPORT_C_INCLUDES := third_party/android/libunwind/include
  include $(PREBUILT_STATIC_LIBRARY)

  include $(CLEAR_VARS)
  LOCAL_MODULE := libunwind-arch
  LOCAL_SRC_FILES := third_party/android/libunwind/$(ARCH_ABI)/libunwind-$(UNW_ARCH).a
  LOCAL_EXPORT_C_INCLUDES := third_party/android/libunwind/include
  include $(PREBUILT_STATIC_LIBRARY)

  include $(CLEAR_VARS)
  LOCAL_MODULE := libunwind-ptrace
  LOCAL_SRC_FILES := third_party/android/libunwind/$(ARCH_ABI)/libunwind-ptrace.a
  LOCAL_EXPORT_C_INCLUDES := third_party/android/libunwind/include
  include $(PREBUILT_STATIC_LIBRARY)

  LOCAL_MODULE := libunwind-dwarf-generic
  LOCAL_SRC_FILES := third_party/android/libunwind/$(ARCH_ABI)/libunwind-dwarf-generic.a
  LOCAL_EXPORT_C_INCLUDES := third_party/android/libunwind/include
  include $(PREBUILT_STATIC_LIBRARY)

  # Upstream capstone compiled from sources with Android NDK toolchain
  LIBCAPSTONE_A := third_party/android/capstone/$(ARCH_ABI)/libcapstone.a
  ifeq ("$(wildcard $(LIBCAPSTONE_A))","")
    $(error libunwind-$(UNW_ARCH). is missing. Please execute \
            'third_party/android/scripts/compile-capstone.sh third_party/android/capstone $(ARCH_ABI)')
  endif
  include $(CLEAR_VARS)
  LOCAL_MODULE := libcapstone
  LOCAL_SRC_FILES := $(LIBCAPSTONE_A)
  LOCAL_EXPORT_C_INCLUDES := third_party/android/capstone/include
  include $(PREBUILT_STATIC_LIBRARY)
endif

# Main honggfuzz module
include $(CLEAR_VARS)

LOCAL_MODULE := honggfuzz
LOCAL_SRC_FILES := honggfuzz.c log.c files.c fuzz.c report.c mangle.c util.c
LOCAL_CFLAGS := -std=c11 -I. \
    -D_GNU_SOURCE \
    -Wall -Wextra -Wno-initializer-overrides -Wno-override-init \
    -Wno-unknown-warning-option -Werror -funroll-loops -O2
LOCAL_LDFLAGS := -lm

ifeq ($(ANDROID_WITH_PTRACE),true)
  LOCAL_C_INCLUDES := third_party/android/libunwind/include third_party/android/capstone/include
  LOCAL_STATIC_LIBRARIES := libunwind libunwind-arch libunwind-ptrace libunwind-dwarf-generic libcapstone
  LOCAL_CFLAGS += -D__HF_USE_CAPSTONE__
  ARCH_SRCS := linux/arch.c linux/ptrace_utils.c linux/perf.c linux/unwind.c
  ARCH := LINUX
  $(info $(shell (echo "********************************************************************")))
  $(info $(shell (echo "Android PTRACE build: Will prevent debuggerd from processing crashes")))
  $(info $(shell (echo "********************************************************************")))
else
  ARCH_SRCS := posix/arch.c
  ARCH := POSIX
  $(info $(shell (echo "********************************************************************")))
  $(info $(shell (echo "Android POSIX build: Will allow debuggerd to also process crashes")))
  $(info $(shell (echo "********************************************************************")))
endif

LOCAL_SRC_FILES += $(ARCH_SRCS)
LOCAL_CFLAGS += -D_HF_ARCH_${ARCH}

include $(BUILD_EXECUTABLE)

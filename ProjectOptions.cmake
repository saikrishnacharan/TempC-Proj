include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(TempC_Proj_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(TempC_Proj_setup_options)
  option(TempC_Proj_ENABLE_HARDENING "Enable hardening" ON)
  option(TempC_Proj_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    TempC_Proj_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    TempC_Proj_ENABLE_HARDENING
    OFF)

  TempC_Proj_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR TempC_Proj_PACKAGING_MAINTAINER_MODE)
    option(TempC_Proj_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(TempC_Proj_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(TempC_Proj_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(TempC_Proj_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(TempC_Proj_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(TempC_Proj_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(TempC_Proj_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(TempC_Proj_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(TempC_Proj_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(TempC_Proj_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(TempC_Proj_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(TempC_Proj_ENABLE_PCH "Enable precompiled headers" OFF)
    option(TempC_Proj_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(TempC_Proj_ENABLE_IPO "Enable IPO/LTO" ON)
    option(TempC_Proj_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(TempC_Proj_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(TempC_Proj_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(TempC_Proj_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(TempC_Proj_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(TempC_Proj_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(TempC_Proj_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(TempC_Proj_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(TempC_Proj_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(TempC_Proj_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(TempC_Proj_ENABLE_PCH "Enable precompiled headers" OFF)
    option(TempC_Proj_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      TempC_Proj_ENABLE_IPO
      TempC_Proj_WARNINGS_AS_ERRORS
      TempC_Proj_ENABLE_USER_LINKER
      TempC_Proj_ENABLE_SANITIZER_ADDRESS
      TempC_Proj_ENABLE_SANITIZER_LEAK
      TempC_Proj_ENABLE_SANITIZER_UNDEFINED
      TempC_Proj_ENABLE_SANITIZER_THREAD
      TempC_Proj_ENABLE_SANITIZER_MEMORY
      TempC_Proj_ENABLE_UNITY_BUILD
      TempC_Proj_ENABLE_CLANG_TIDY
      TempC_Proj_ENABLE_CPPCHECK
      TempC_Proj_ENABLE_COVERAGE
      TempC_Proj_ENABLE_PCH
      TempC_Proj_ENABLE_CACHE)
  endif()

  TempC_Proj_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (TempC_Proj_ENABLE_SANITIZER_ADDRESS OR TempC_Proj_ENABLE_SANITIZER_THREAD OR TempC_Proj_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(TempC_Proj_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(TempC_Proj_global_options)
  if(TempC_Proj_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    TempC_Proj_enable_ipo()
  endif()

  TempC_Proj_supports_sanitizers()

  if(TempC_Proj_ENABLE_HARDENING AND TempC_Proj_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR TempC_Proj_ENABLE_SANITIZER_UNDEFINED
       OR TempC_Proj_ENABLE_SANITIZER_ADDRESS
       OR TempC_Proj_ENABLE_SANITIZER_THREAD
       OR TempC_Proj_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${TempC_Proj_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${TempC_Proj_ENABLE_SANITIZER_UNDEFINED}")
    TempC_Proj_enable_hardening(TempC_Proj_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(TempC_Proj_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(TempC_Proj_warnings INTERFACE)
  add_library(TempC_Proj_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  TempC_Proj_set_project_warnings(
    TempC_Proj_warnings
    ${TempC_Proj_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(TempC_Proj_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    TempC_Proj_configure_linker(TempC_Proj_options)
  endif()

  include(cmake/Sanitizers.cmake)
  TempC_Proj_enable_sanitizers(
    TempC_Proj_options
    ${TempC_Proj_ENABLE_SANITIZER_ADDRESS}
    ${TempC_Proj_ENABLE_SANITIZER_LEAK}
    ${TempC_Proj_ENABLE_SANITIZER_UNDEFINED}
    ${TempC_Proj_ENABLE_SANITIZER_THREAD}
    ${TempC_Proj_ENABLE_SANITIZER_MEMORY})

  set_target_properties(TempC_Proj_options PROPERTIES UNITY_BUILD ${TempC_Proj_ENABLE_UNITY_BUILD})

  if(TempC_Proj_ENABLE_PCH)
    target_precompile_headers(
      TempC_Proj_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(TempC_Proj_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    TempC_Proj_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(TempC_Proj_ENABLE_CLANG_TIDY)
    TempC_Proj_enable_clang_tidy(TempC_Proj_options ${TempC_Proj_WARNINGS_AS_ERRORS})
  endif()

  if(TempC_Proj_ENABLE_CPPCHECK)
    TempC_Proj_enable_cppcheck(${TempC_Proj_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(TempC_Proj_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    TempC_Proj_enable_coverage(TempC_Proj_options)
  endif()

  if(TempC_Proj_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(TempC_Proj_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(TempC_Proj_ENABLE_HARDENING AND NOT TempC_Proj_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR TempC_Proj_ENABLE_SANITIZER_UNDEFINED
       OR TempC_Proj_ENABLE_SANITIZER_ADDRESS
       OR TempC_Proj_ENABLE_SANITIZER_THREAD
       OR TempC_Proj_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    TempC_Proj_enable_hardening(TempC_Proj_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()

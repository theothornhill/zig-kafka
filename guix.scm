(use-modules
 (guix gexp)
 (guix git-download)
 (guix utils)
 (guix packages)
 (guix build-system zig)
 (guix build-system gnu)
 (gnu packages curl)
 (gnu packages cyrus-sasl)
 (gnu packages python)
 (gnu packages tls)
 (gnu packages zig)
 (gnu packages zig-xyz)
 (gnu packages base)
 ((gnu packages compression) #:prefix compression:)
 ((guix licenses) #:prefix license:))

(define vcs-file?
  (or (git-predicate (current-source-directory))
      (const #t)))

(define-public librdkafka
  (package
    (name "librdkafka")
    (version "2.6.0")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/confluentinc/librdkafka")
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
              (sha256
               (base32 "1kjgz9ynq2rwpp373jnly1ns4iaqpscck5lmnzim5hkzsyxrafa2"))))
    (build-system gnu-build-system)
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (replace 'configure
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((out (assoc-ref outputs "out")))
               (invoke "./configure" (string-append "--prefix=" out)))))
         (replace 'build (lambda _ (invoke "make")))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (libdir (string-append out "/lib"))
                    (includedir (string-append out "/include/librdkafka"))
                    (pkgconfigdir (string-append libdir "/pkgconfig"))
                    (docdir (string-append out "/share/doc/librdkafka"))
                    (examplesdir (string-append docdir "/examples")))

               ;; Ensure directories have been created
               (mkdir-p includedir)
               (mkdir-p libdir)
               (mkdir-p pkgconfigdir)
               (mkdir-p docdir)
               (mkdir-p examplesdir)

               ;; Manually install the header files and static libraries
               (install-file "src/rdkafka.h" includedir)
               (install-file "src/rdkafka_mock.h" includedir)
               (for-each (lambda (file)
                           (install-file file libdir))
                         (find-files "src" ".*\\.a$"))

               ;; Install the shared library and create the symbolic link
               (install-file "src/librdkafka.so.1" libdir)
               (symlink "librdkafka.so.1" (string-append libdir "/librdkafka.so"))

               ;; Install pkg-config files
               (install-file "src/rdkafka.pc" pkgconfigdir)
               (install-file "src/rdkafka-static.pc" pkgconfigdir)

               ;; Install documentation
               (install-file "README.md" docdir)
               (copy-recursively "examples" examplesdir)
               (for-each (lambda (file)
                           (install-file file docdir))
                         '("CONFIGURATION.md" "INTRODUCTION.md" "LICENSE"
                           "LICENSES.txt" "STATISTICS.md" "CHANGELOG.md"))))))))
    (propagated-inputs (list compression:zlib cyrus-sasl openssl curl compression:lz4))
    (native-inputs (list python-wrapper))
    (home-page "https://github.com/confluentinc/librdkafka")
    (synopsis "Apache Kafka C client library")
    (description "librdkafka is a C library implementation of the Apache Kafka protocol,
containing both Producer and Consumer support.")
    (license license:bsd-2)))

(define build-phases
  #~(modify-phases
        %standard-phases
      (replace 'build (lambda* (#:key
                                zig-build-flags
                                zig-build-target
                                ;; "safe", "fast" or "small", empty for a "debug" build.
                                zig-release-type
                                parallel-build?
                                skip-build?
                                #:allow-other-keys)
                        "Build a given Zig package."
                        (when (not skip-build?)
                          (setenv "DESTDIR" "out")
                          (let* ( ;; (arguments (zig-arguments))
                                 (call `("zig" "build"
                                         "--prefix"             ""
                                         "--prefix-lib-dir"     "lib"
                                         "--prefix-exe-dir"     "bin"
                                         "--prefix-include-dir" "include"
                                         "--verbose"
                                         ,@zig-build-flags)))
                            (format #t "running: ~s~%" call)
                            (apply invoke call)))))

      (delete 'unpack-dependencies)
      (add-after
          'unpack
          'unpack-zig
        (lambda _
          (for-each
           (match-lambda
             ((dst src)
              (let* ((dest (string-append "zig-cache/" dst)))
                (mkdir-p dest)
                (if (string-contains src ".tar.gz")
                    (invoke "tar" "-xf" src "-C" dest "--strip-components=1")
                    (copy-recursively src dest)))))
           `(("1220152dda3c1c2b1199537fb062042f04585c21189b930df0076cac791e2c220bc3"
              #$(origin
                  (method git-fetch)
                  (uri (git-reference
                        (url "https://github.com/confluentinc/librdkafka")
                        (commit "7fc5a59826ee1e1dee3236b1e43180cc22cfb496")))
                  (file-name "upstream")
                  (sha256
                   (base32 "1kjgz9ynq2rwpp373jnly1ns4iaqpscck5lmnzim5hkzsyxrafa2"))))
             ("122034ab2a12adf8016ffa76e48b4be3245ffd305193edba4d83058adbcfa749c107"
              #$(origin
                  (method git-fetch)
                  (uri (git-reference
                        (url "https://github.com/allyourcodebase/zlib")
                        (commit "0918e87b7629b9c6a50a08edd0ce30d849758faf")))
                  (file-name "zlib")
                  (sha256
                   (base32 "0s4cr67cr14n3lw9s0zbi1gxlrzm3j2dvj1sm76s2pkwj9dp9jr5"))))
             ("122040924472b1c510a7058596d43fb9461dcc20406f681eb9c2f6443375d2f571c4"
              #$(origin
                  (method git-fetch)
                  (uri (git-reference
                        (url "https://github.com/allyourcodebase/zstd")
                        (commit "ea25e89037dc251a3ba50a5005e2c8566eb3c2bd")))
                  (file-name "zstd")
                  (sha256
                   (base32 "066jr5787bp812vkzh2zi71xq40i16jd4z7xv3xkyh94vvfmy5rf"))))
             ("12205df4790849e6ab600128051b962361901b706f75cbffe2eb8da09a81069f9011"
              #$(origin
                  (method git-fetch)
                  (uri (git-reference
                        (url "https://github.com/facebook/zstd")
                        (commit "794ea1b0afca0f020f4e57b6732332231fb23c70")))
                  (file-name "zstd")
                  (sha256
                   (base32 "066jr5787bp812vkzh2zi71xq40i16jd4z7xv3xkyh94vvfmy5rf"))))
             ("1220fed0c74e1019b3ee29edae2051788b080cd96e90d56836eea857b0b966742efb"
              #$(origin
                  (method git-fetch)
                  (uri (git-reference
                        (url "https://github.com/madler/zlib")
                        (commit "ef24c4c7502169f016dcd2a26923dbaf3216748c")))
                  (file-name "zlib")
                  (sha256
                   (base32 "1qfzkl3iyl41pxgvm62431s78kpcakdpiqfq0pc5cnkarskhw94a"))))))))))

(define build-flags
  #~(list
     "--system"
     (string-append (getenv "TMPDIR") "/source/zig-cache")))

(package
  (name "zig-kafka")
  (version "0.0.1")
  (source (local-file "." "zig-kafka" #:recursive? #t #:select? vcs-file?))
  (build-system zig-build-system)
  (arguments
   (list #:install-source? #t
         #:tests? #t
         #:zig-build-flags build-flags
         #:zig-test-flags build-flags
         #:modules
         '((guix build zig-build-system)
           (guix build utils)
           (ice-9 match))
         #:phases build-phases))
  (native-inputs (list zig zig-zls))
  (propagated-inputs
   (list openssl curl python-wrapper cyrus-sasl librdkafka))
  (home-page "https://ziglang.org/")
  (synopsis "General-purpose programming language and toolchain")
  (description "Zig implementation over librdkafka")
  (license license:bsd-2))

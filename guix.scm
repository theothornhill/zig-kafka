(use-modules (guix git)
             (guix gexp)
             (guix git-download)
             (guix utils)
             (guix download)
             (guix packages)
             (guix modules)
             (guix licenses)
             (guix build-system)
             (guix build-system zig)
             (guix build-system gnu)
             (gnu packages)
             (gnu packages curl)
             (gnu packages cyrus-sasl)
             (gnu packages python)
             ((gnu packages tls) #:prefix tls:)
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
   (inputs (list compression:zlib
                 cyrus-sasl
                 tls:openssl
                 curl
                 compression:lz4))
   (native-inputs `(("python" ,python-wrapper)))
   (propagated-inputs (list compression:zlib))
   (home-page "https://github.com/confluentinc/librdkafka")
   (synopsis "Apache Kafka C client library")
   (description "librdkafka is a C library implementation of the Apache Kafka protocol,
containing both Producer and Consumer support.")
   (license license:bsd-2)))

(define build-phases
  #~(modify-phases
        %standard-phases
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
           `(("12206c70c128fb22ba38ed29a1d3e07a1aee096b6c46af3f601b923fcf07d6dd166b"
              #$(origin
                  (method git-fetch)
                  (uri (git-reference
                        (url "https://github.com/theothornhill/zig-avro")
                        (commit "7ffe402975bba70fbf833de9a9feb3b1387cb71f")))
                  (file-name "zig-avro")
                  (sha256
                   (base32 "15zciadvjz01brv4myz1y6jlifn5sjzcdz0c2ki4ifhb16ph1s4i"))))
             ("1220d9e8d4fc3d9f425b9be4c890c97c35dee5b4c17ee8d00e61140750c10bed7c13"
              #$(origin
                  (method git-fetch)
                  (uri (git-reference
                        (url "https://github.com/theothornhill/zig-typeid")
                        (commit "1b7c6869d184097e0d1071b2d4666946d2c012c9")))
                  (file-name "zig-typeid")
                  (sha256
                   (base32 "1p0kpkhpm2kc3yir3zf4zjzgrgmw48zzh9p45jd99jbp3p0rryx0"))))
             ("12204511340c69f7aa8c2e15aa53ab722f1aab29aa16dad7bd6fb2676a281823b23f"
              #$(origin
                  (method git-fetch)
                  (uri (git-reference
                        (url "https://github.com/theothornhill/zig-kafka")
                        (commit "b2dffc0388cc46a6868c5b3622d7111f01f713b7")))
                  (file-name "zig-kafka")
                  (sha256
                   (base32 "1szr6vz44l8nil77dimy3x4s0ipwzvsly2103jfviybwiii9v4mr"))))
             ("1220d001e83e87eb6b489172efceb840fd2bb9a7fda0bf275b21797039f6dbdc1682"
              #$(origin
                  (method git-fetch)
                  (uri (git-reference
                        (url "https://github.com/helgeholm/ecs-log-formatter")
                        (commit "2ab5eeeae781cd47fc16281615750c0e06e7e477")))
                  (file-name "ecs-log-formatter")
                  (sha256
                   (base32 "1lrabhsxwjqkl9fj8mzymirvknbrkygs77dszm2b3gf4ygvrgrh1"))))
             ("1220152dda3c1c2b1199537fb062042f04585c21189b930df0076cac791e2c220bc3"
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
  (native-inputs `(("libssl" ,tls:openssl)
                   ("libcurl" ,curl)
                   ("python" ,python-wrapper)
                   ("libsasl2" ,cyrus-sasl)
                   ("librdkafka" ,librdkafka)))
  (home-page "https://ziglang.org/")
  (synopsis "General-purpose programming language and toolchain")
  (description "Zig implementation over librdkafka")
  (license license:bsd-2))

class Metview < Formula
  desc "Meteorological workstation software"
  homepage "https://metview.readthedocs.io/en/latest/"
  url "https://confluence.ecmwf.int/download/attachments/51731119/MetviewBundle-2024.2.0-Source.tar.gz"
  version "5.21.1"
  sha256 "0493e43f475eccbaa722794b58f4d6793c2d57d76887f3dda1801dd275bfb4c0"
  license "Apache-2.0"

  livecheck do
    url "https://confluence.ecmwf.int/display/METV/The+Metview+Source+Bundle"
    regex(%r{>\s*Metview\s*<.+?<td[^>]*?>\s*v?(\d+(?:\.\d+)+)\s*</td}im)
  end

  bottle do
    sha256 arm64_sonoma:   "1c8be3975fbbd7a3bfcc556d5df08531e85c745e2144ce3e98a26bf8cef163bf"
    sha256 arm64_ventura:  "c6412be971a2a0efb4ae7b4c6ae9e0e6b2672e4c2f179323bd27ada51bb5d106"
    sha256 arm64_monterey: "e486cdf27c06adfecb3d93c10ce2ea3410f33e20fee3c816bf1af9542d6f6fd8"
    sha256 sonoma:         "8fdcd1ca518799ca08f3c462ce510aaad3e84557bbbf33943d9cef1df19de816"
    sha256 ventura:        "1db3dfd441d1f7d924c64df5d2fc79a53e7b29196b7d3171c0d01c99726305ae"
    sha256 monterey:       "868eb7b9dd7bf86e2817b65e95ba30941a2063ac7b5d7811aa13e137970ca8be"
    sha256 x86_64_linux:   "69268c013f5e054fa8cb985a1eaa7e19867903dc25e096d84faec340f1cce46d"
  end

  depends_on "cmake" => :build
  depends_on "pkg-config" => :build
  depends_on "cairo"
  depends_on "eccodes"
  depends_on "eigen"
  depends_on "fftw"
  depends_on "gdbm"
  depends_on "netcdf"
  depends_on "openssl@3"
  depends_on "pango"
  depends_on "proj"
  depends_on "qt"

  uses_from_macos "bison" => :build
  uses_from_macos "flex"  => :build

  on_linux do
    depends_on "libtirpc"
  end

  def install
    args = %W[
      -DBUNDLE_SKIP_ECCODES=1
      -DENABLE_MIR_DOWNLOAD_MASKS=OFF
      -DENABLE_BUILD_TOOLS=OFF
      -DENABLE_ECKIT_CMD=OFF
      -DFFTW_PATH=#{Formula["fftw"].opt_prefix}
    ]

    if OS.linux?
      args += [
        "-DRPC_PATH=#{Formula["libtirpc"].opt_prefix}",
        "-DRPC_INCLUDE_DIR=#{Formula["libtirpc"].opt_include}/tirpc",
      ]
    end

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"

    # Avoid references to Homebrew shims directory
    # (ecbuild stores some references to the build directory - not used, so we can remove them)
    rm lib/"metview-bundle/bin/metview_bin/compile"
    rm_r lib/"metview-bundle/lib/pkgconfig"
    rm_r lib/"metview-bundle/include"
  end

  test do
    # test that the built-in programming language can print a string
    (testpath/"test_binary_run_hello.mv").write <<~EOS
      print("Hello world")
    EOS
    binary_output = shell_output("#{bin}/metview -nocreatehome -b test_binary_run_hello.mv")
    assert_match "Hello world", binary_output

    # test that the built-in programming language can compute a number
    (testpath/"test_binary_run_maths.mv").write <<~EOS
      print(6*7)
    EOS
    binary_output = shell_output("#{bin}/metview -nocreatehome -b test_binary_run_maths.mv")
    assert_match "42", binary_output

    # test that Metview is linked properly with eccodes and magics and can produce a plot from GRIB data
    (testpath/"test_binary_run_grib_plot.mv").write <<~EOS
      gpt = create_geo(latitudes:|5, 10, 15|, longitudes:|30, 40, 35|, values: |5, 1, 3|)
      grib = geo_to_grib(geopoints: gpt, grid: [5,5])
      grid_shading = mcont(
        contour_shade                  : "on",
        contour_shade_technique        : "grid_shading")
      setoutput(png_output(output_name:"test"))
      plot(grib, grid_shading)
    EOS
    system "#{bin}/metview", "-nocreatehome", "-b", "test_binary_run_grib_plot.mv"
    assert_predicate testpath/"test.1.png", :exist?
  end
end

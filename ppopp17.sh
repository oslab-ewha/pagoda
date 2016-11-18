#!/bin/sh

echo $PWD

# Compile all benchmarks
cd matrixMul/pagoda

echo "##  Compiling matrixMul pagoda  ##"
make clean
make

cd ..
cd baseline
echo "##  Compiling matrixMul baseline  ##"
make clean
make

cd ../..
cd convolution/pagoda
echo "##  Compiling convolution pagoda  ##"
make clean
make

cd ..
cd baseline
echo "##  Compiling convolution baseline  ##"
make clean
make

cd ../..
cd dct/pagoda
echo "##  Compiling dct pagoda  ##"
make clean
make

cd ..
cd baseline
echo "##  Compiling dct baseline  ##"
make clean
make

cd ../..
cd des/pagoda
echo "##  Compiling des pagoda ## "
make clean
make

cd ..
cd baseline
echo "##  Compiling des baseline  ##"
make clean
make

cd ../..
cd filterbank/pagoda
echo "## Compiling filterbank pagoda ##"
make clean
make

cd ..
cd baseline
echo "##  Compiling filterbank baseline  ##"
make clean
make

cd ../..
cd mandelbrot/pagoda
echo "##  Compiling mandelbrot pagoda  ##"
make clean
make

cd ..
cd baseline
echo "##  Compiling mandelbrot baseline  ##"
make clean
make

cd ../..
cd multiwork/pagoda
echo "## Compiling multiwork pagoda  ##"
make clean
make

cd ..
cd baseline
echo "##  Compiling multiwork baseline  ##"
make clean
make

cd ../..
cd sparseLU/pagoda
echo "##  Compiling sparseLU pagoda  ##"
make clean
make

cd ..
cd baseline
echo "##  Compiling sparseLU baseline  ##"
make clean
make

cd ../../
cd matrixMul/pagoda
echo "# Running matrixMul Pagoda #"
sh run

cd ..
cd baseline
echo "# Running matrixMul CUDA baseline #"
sh run

cd ../../
cd filterbank/pagoda
echo "# Running filterbank Pagoda #"
sh run

cd ..
cd baseline
echo "# Running filterbank CUDA baseline #"
sh run


cd ../../
cd convolution/pagoda
echo "# Running convolution Pagoda #"
sh run

cd ..
cd baseline
echo "# Running convolution CUDA baseline #"
sh run

cd ../../
cd dct/pagoda
echo "# Running matrixMul Pagoda #"
sh run

cd ..
cd baseline
echo "# Running dct CUDA baseline #"
sh run

cd ../../
cd beamformer/pagoda
echo "# Running beamformer Pagoda #"
sh run

cd ..
cd baseline
echo "# Running beamformer CUDA baseline #"
sh run

cd ../../
cd mandelbrot/pagoda
echo "# Running mandelbrot Pagoda #"
sh run

cd ..
cd baseline
echo "# Running mandelbrot CUDA baseline #"
sh run

cd ../../
cd multiwork/pagoda
echo "# Running multiprogramming Pagoda #"
sh run

cd ..
cd baseline
echo "# Running multiprogramming CUDA baseline #"
sh run


echo $PWD

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <math.h>
#include <sys/time.h>

#include <cuda_runtime.h>
#include <helper_cuda.h>
#include "../../common/para.h"

#define TKK_NUM 19200
#define BTT_NUM (TKK_NUM/TK_NUM)
#define NUM_CHAN (TK_NUM * BTT_NUM)

double my_timer()
{
struct timeval time;
double _ret_val_0;
gettimeofday(( & time), 0);
_ret_val_0=(time.tv_sec+(time.tv_usec/1000000.0));
return _ret_val_0;
}

void BeamFirSetup(float *weight, float *buffer, int n);
void InputGenerate(float *input, int n);

__global__ void d_BeamFirFilter(int len, int decimation_ratio,
                        float *weight, float *buffer,
                        float *in, float *out, int thread);
void BeamFirFilter(int len,
                   float *weight, float *buffer,
                   float *in, float *out);


int main(){

  	int i, j;
  	float **h_coarse_weight, **h_coarse_buffer;
  	float **d_coarse_weight, **d_coarse_buffer;

  	float **h_inputs, **h_predec, **h_postdec;
  	float **d_inputs, **d_predec, **d_postdec;
  	float **hh_postdec;

  	int num_thread[NUM_CHAN];
  	int num_size[NUM_CHAN];
  	FILE *f;
  	double start_timer, end_timer;

	cudaSetDevice(0);
  	setenv("CUDA_DEVICE_MAX_CONNECTIONS", "32", 1);

  	cudaStream_t *beam_stream;
  	beam_stream = (cudaStream_t*)malloc(NUM_CHAN*sizeof(cudaStream_t));
  	for(i = 0; i < NUM_CHAN; i++) checkCudaErrors(cudaStreamCreate(&beam_stream[i]));


  	f = fopen("rand4.txt", "r");
  	for(i = 0; i < NUM_CHAN; i++)
    		fscanf(f, "%1d", &num_thread[i]);

  	fclose(f);

  	for(i = 0; i < NUM_CHAN; i++){
    		num_size[i] = (num_thread[i]*16)*(num_thread[i]*16);
  	}


  	d_coarse_weight = (float**)malloc(NUM_CHAN * sizeof(float *));
  	d_coarse_buffer = (float**)malloc(NUM_CHAN * sizeof(float *));
  	h_coarse_weight = (float**)malloc(NUM_CHAN * sizeof(float *));
  	h_coarse_buffer = (float**)malloc(NUM_CHAN * sizeof(float *));

  	h_inputs = (float**)malloc(NUM_CHAN * sizeof(float *));
  	h_predec = (float**)malloc(NUM_CHAN * sizeof(float *));
  	h_postdec = (float**)malloc(NUM_CHAN * sizeof(float *));
  	d_inputs = (float**)malloc(NUM_CHAN * sizeof(float *));
  	d_predec = (float**)malloc(NUM_CHAN * sizeof(float *));
  	d_postdec = (float**)malloc(NUM_CHAN * sizeof(float *));
  	hh_postdec = (float**)malloc(NUM_CHAN * sizeof(float *));

  	for(i = 0; i < NUM_CHAN; i++){
    		checkCudaErrors(cudaHostAlloc(&h_inputs[i], 2*num_size[i]*sizeof(float), cudaHostAllocDefault));
    		checkCudaErrors(cudaHostAlloc(&h_postdec[i], 2*num_size[i]*sizeof(float), cudaHostAllocDefault));
    		checkCudaErrors(cudaHostAlloc(&h_coarse_weight[i], 2*num_size[i]*sizeof(float), cudaHostAllocDefault));
    		checkCudaErrors(cudaHostAlloc(&h_coarse_buffer[i], 2*num_size[i]*sizeof(float), cudaHostAllocDefault));

    		checkCudaErrors(cudaMalloc(&d_inputs[i], 2* num_size[i]*sizeof(float)));
    		checkCudaErrors(cudaMalloc(&d_predec[i], 2* num_size[i]*sizeof(float)));
    		checkCudaErrors(cudaMalloc(&d_postdec[i], 2* num_size[i]*sizeof(float)));
    		checkCudaErrors(cudaMalloc(&d_coarse_weight[i], 2* num_size[i]*sizeof(float)));
    		checkCudaErrors(cudaMalloc(&d_coarse_buffer[i], 2* num_size[i]*sizeof(float)));
    		h_predec[i] = (float*)malloc(2*num_size[i]*sizeof(float));
    		hh_postdec[i] = (float*)malloc(2*num_size[i]*sizeof(float));


  	}
  
  	// init data
	printf("Inputs are generted\n");
  	for(i = 0; i < NUM_CHAN; i++){
    		BeamFirSetup(h_coarse_weight[i], h_coarse_buffer[i], num_size[i]);
    		InputGenerate(h_inputs[i], num_size[i]);
  	}

  	// input transfer
  	for(i = 0; i < NUM_CHAN; i++){
    		checkCudaErrors(cudaMemcpyAsync(d_inputs[i], h_inputs[i], 2*num_size[i]*sizeof(float), cudaMemcpyHostToDevice, beam_stream[i]));
    		checkCudaErrors(cudaMemcpyAsync(d_coarse_weight[i], h_coarse_weight[i], 2*num_size[i]*sizeof(float), cudaMemcpyHostToDevice, beam_stream[i]));
    		checkCudaErrors(cudaMemcpyAsync(d_coarse_buffer[i], h_coarse_buffer[i], 2*num_size[i]*sizeof(float), cudaMemcpyHostToDevice, beam_stream[i]));
    
  	}
  	checkCudaErrors(cudaDeviceSynchronize());

	printf("GPU program is running\n");
  	// task running
  	start_timer = my_timer();
  	for(i = 0; i < NUM_CHAN; i++){
    		d_BeamFirFilter<<<1, num_thread[i]*32, 0, beam_stream[i]>>>(num_size[i], 1,
                        d_coarse_weight[i], d_coarse_buffer[i],
                        d_inputs[i], d_predec[i], num_thread[i]*32);

  	}
  	checkCudaErrors(cudaDeviceSynchronize());

  	for(i = 0; i < NUM_CHAN; i++){
    		d_BeamFirFilter<<<1, num_thread[i]*32, 0, beam_stream[i]>>>(num_size[i], 1,
                        d_coarse_weight[i], d_coarse_buffer[i],
                        d_predec[i], d_postdec[i], num_thread[i]*32);

  	}
  	checkCudaErrors(cudaDeviceSynchronize());
  	end_timer = my_timer();
  	printf("Beamformer CUDA baseline elapsed Time: %lf sec.\n", end_timer - start_timer);

  	// copy back
  	start_timer = my_timer();
  	for (i = 0; i < NUM_CHAN; i++) {
    		checkCudaErrors(cudaMemcpyAsync(h_postdec[i], d_postdec[i], 2*num_size[i]*sizeof(float), cudaMemcpyDeviceToHost, beam_stream[i]));
  	}
  	checkCudaErrors(cudaDeviceSynchronize());
#if 0
  	//host task running
  	start_timer = my_timer();
  	for(i = 0; i < NUM_CHAN; i++){
    		BeamFirFilter(num_size[i],
                   h_coarse_weight[i], h_coarse_buffer[i],
                   h_inputs[i], h_predec[i]);
  	}
  	for(i = 0; i < NUM_CHAN; i++){
    		BeamFirFilter(num_size[i],
                   h_coarse_weight[i], h_coarse_buffer[i],
                   h_predec[i], hh_postdec[i]);
  	}
  	end_timer = my_timer();
  	printf("CPU exec. time:%lf\n", end_timer - start_timer);

	printf("verifying\n");
	int flag = 0;
  	//verifiy
  	for(i = 0; i < 1; i++){
    		for(j = 0; j < num_size[i]; j++){
      			if(abs(h_postdec[i][j] - hh_postdec[i][j]) > 0.1){
        			printf("Error:%f, %f, %d, %d\n", h_postdec[i][j], hh_postdec[i][j], i, j);
				flag = 1;
        			break;
      			}
    		}
  	}

	if(!flag) printf("verify successfully\n");
#endif
  	//free mem
  	for(i = 0; i < NUM_CHAN; i++){

    		checkCudaErrors(cudaStreamDestroy(beam_stream[i]));
    		checkCudaErrors(cudaFreeHost(h_inputs[i]));
    		checkCudaErrors(cudaFreeHost(h_postdec[i]));
    		checkCudaErrors(cudaFreeHost(h_coarse_weight[i]));
    		checkCudaErrors(cudaFreeHost(h_coarse_buffer[i]));

    		checkCudaErrors(cudaFree(d_inputs[i]));
    		checkCudaErrors(cudaFree(d_predec[i]));
    		checkCudaErrors(cudaFree(d_postdec[i]));
    		checkCudaErrors(cudaFree(d_coarse_weight[i]));
    		checkCudaErrors(cudaFree(d_coarse_buffer[i]));
    		free(h_predec[i]);
    		free(hh_postdec[i]);


  	}
  	free(d_coarse_weight);
  	free(d_coarse_buffer);
  	free(h_coarse_weight);
  	free(h_coarse_buffer);

 	free(h_inputs);
  	free(h_predec);
  	free(h_postdec);
  	free(d_inputs);
  	free(d_predec);
  	free(d_postdec);
  	free(hh_postdec);



	return 0;
}

void BeamFirSetup(float *weight, float *buffer, int n){

  int i;
  for(i = 0; i < n; i++){
    int idx = i + 1;
    //weight[i*2] = sin(idx) / ((float)idx);
    //weight[i*2+1] = cos(idx) / ((float)idx);
    weight[i*2] = 0.001;
    weight[i*2+1] = 0.002;
    buffer[i*2] = 0.0;
    buffer[i*2+1] = 0.0;
  }
}

void InputGenerate(float *input, int n){
  int i;
  for(i = 0; i < n; i++){
    //input[2*i] = sqrt(i);
    //input[2*i+1] = sqrt(i) + 1;
    input[2*i] = 0.01;
    input[2*i+1] = 0.02;
  }
}

void BeamFirFilter(int len,
		   float *weight, float *buffer,
                   float *in, float *out)
{
  /* Input must be exactly 2*decimation_ratio long; output must be
   * exactly 2 long. */
  int i, j;
  int modPos;
  int mask, mask2;
  mask = len - 1;
  mask2 = 2 * len - 1;
  for(j = 0; j < len; j++){
    float real_curr = 0;
    float imag_curr = 0;
    modPos = 2*(len - 1 - (j & mask));
    buffer[modPos] = in[j * 2 ];
    buffer[modPos+1] = in[j * 2 + 1];

    /* Profiling says: this is the single inner loop that matters! */
    for (i = 0; i < 2*len; i+=2) {
      float rd = buffer[modPos];
      float id = buffer[modPos+1];
      float rw = weight[i];
      float iw = weight[i+1];
      float rci = rd * rw + id * iw;
      /* sign error?  this is consistent with StreamIt --dzm */
      float ici = id * rw + rd * iw;
      real_curr += rci;
      imag_curr += ici;
      modPos = (modPos + 2) & mask2;
    }
    out[j * 2] = real_curr;
    out[j * 2 + 1] = imag_curr;
  }
}

__global__ void d_BeamFirFilter(int len, int decimation_ratio,
                        float *weight, float *buffer,
                        float *in, float *out, int thread)
{
  /* Input must be exactly 2*decimation_ratio long; output must be
   * exactly 2 long. */
  int tid = threadIdx.x + blockIdx.x *blockDim.x;
  int i, j;
  int modPos;
  int mask, mask2;
  mask = len - 1;
  mask2 = 2 * len - 1;
  //for(k = 0; k < TD_NUM; k++){
  if(tid < thread){
    for(j = 0; j < (len/thread); j++){
      float real_curr = 0;
      float imag_curr = 0;
      modPos = 2*(len - 1 - ((j*thread+tid) & mask));
      buffer[modPos] = in[(j*thread+tid) * decimation_ratio * 2 ];
      buffer[modPos+1] = in[(j*thread+tid) * decimation_ratio * 2 + 1];

      /* Profiling says: this is the single inner loop that matters! */
      for (i = 0; i < 2*len; i+=2) {
        float rd = buffer[modPos];
        float id = buffer[modPos+1];
        float rw = weight[i];
        float iw = weight[i+1];
        float rci = rd * rw + id * iw;
        /* sign error?  this is consistent with StreamIt --dzm */
        float ici = id * rw + rd * iw;
        real_curr += rci;
        imag_curr += ici;
        modPos = (modPos + 2) & mask2;
      }
      out[(j*thread+tid) * 2] = real_curr;
      out[(j*thread+tid) * 2 + 1] = imag_curr;
    }
  }
}


#include "kernel.h"
#include "packet.h"

#define __syncthreads_block(blockIndex, thread_num) asm volatile("bar.sync %0, %1;" :: "r"(blockIndex), "r"(thread_num));
extern __device__ int syncID;
extern __device__ int threadNum;

__device__ void mult_gpu(int *A, int *B, int *C, int size, int baseTid){
  int tid = baseTid + (threadIdx.x & 0x1f);
  int i, k;
  int sum = 0;
  if(tid < TDD_NUM){
    for(i = 0; i < (size*size/TDD_NUM); i++){
      for(k = 0; k < size; k++){
        sum += A[((i*TDD_NUM+tid)/size)*size+k] * B[k*size+((i*TDD_NUM+tid)%size)];
      }
      C[((i*TDD_NUM+tid)/size)*size+((i*TDD_NUM+tid)%size)] = sum;
      if(k == size) sum = 0;
    }
  }
}

void mult(int *A, int *B, int *C, int size){
  int i, j, k;
  int sum = 0;
  for(j = 0; j < TDD_NUM; j++)
    for(i = 0; i < (size*size/TDD_NUM); i++){
      for(k = 0; k < size; k++){
        sum += A[((i*TDD_NUM+j)/size)*size+k] * B[k*size+((i*TDD_NUM+j)%size)];
      }
      C[((i*TDD_NUM+j)/size)*size+((i*TDD_NUM+j)%size)] = sum;
      if(k == size) sum = 0;
    }
}

__device__ void explode ( float x, float y, int *value){
  int k;
  float x1;
  float x2;
  float y1;
  float y2;
  //int value;
  *value = 0;

  x1 = x;
  y1 = y;

  for ( k = 1; k <= count_max; k++ )
  {
    x2 = x1 * x1 - y1 * y1 + x;
    y2 = 2.0 * x1 * y1 + y;

    if ( x2 < -2.0 || 2.0 < x2 || y2 < -2.0 || 2.0 < y2 )
    {
      *value = k;
      //if(k > 1000)
         //printf("k:%d\n", k);
      break;
    }
    x1 = x2;
    y1 = y2;
  }
}

__device__ void get_pixel(int *count, float *index, int baseTid){

  int tid = baseTid + (threadIdx.x & 0x1f);

  int i;
  float x, y;
  if(tid < TDD_NUM){
    for(i = 0; i < (n*n/TDD_NUM); i++){
    //for(j = 0; j < TDD_NUM; j++){
  //for ( i = 0; i < n; i++ ){
    //for ( j = 0; j < n; j++ ){
      x = ( ( float ) (     (i*TDD_NUM+tid)%n     ) * (x_max + *index)
          + ( float ) ( n - ((i*TDD_NUM+tid)%n) - 1 ) * (x_min + *index) )
          / ( float ) ( n     - 1 );

      y = ( ( float ) (     (i*TDD_NUM+tid)/n     ) * (y_max + *index)
          + ( float ) ( n - ((i*TDD_NUM+tid)/n) - 1 ) * (y_min + *index) )
          / ( float ) ( n     - 1 );

      explode ( x, y, &count[((i*TDD_NUM+tid)/n) + ((i*TDD_NUM+tid)%n) * n] );
    }
  }

}

void h_explode ( float x, float y, int *value){
  int k;
  float x1;
  float x2;
  float y1;
  float y2;
  //int value;
  *value = 0;

  x1 = x;
  y1 = y;

  for ( k = 1; k <= count_max; k++ )
  {
    x2 = x1 * x1 - y1 * y1 + x;
    y2 = 2.0 * x1 * y1 + y;

    if ( x2 < -2.0 || 2.0 < x2 || y2 < -2.0 || 2.0 < y2 )
    {
      *value = k;
      //if(k > 1000)
         //printf("k:%d\n", k);
      break;
    }
    x1 = x2;
    y1 = y2;
  }
}

void h_get_pixel(int *count, float index){

  int i, j;
  float x, y;
  for ( i = 0; i < n; i++ )
  {
    for ( j = 0; j < n; j++ )
    {
      x = ( ( float ) (     j     ) * (x_max + index)
          + ( float ) ( n - j - 1 ) * (x_min + index) )
          / ( float ) ( n     - 1 );

      y = ( ( float ) (     i     ) * (y_max + index)
          + ( float ) ( n - i - 1 ) * (y_min + index) )
          / ( float ) ( n     - 1 );

      h_explode ( x, y, &count[i + j * n] );
    }
  }

}


__device__ void FBCore(float *r, float *H, float *Vect_H, float *Vect_Dn, 
			float *Vect_Up, float *Vect_F, float *F, int baseTid, int barId){
  int tid = baseTid + (threadIdx.x & 0x1f);
  int j, k;

  //convolving H
  if(tid < TDD_NUM){
    for (j=0; j< (N_sim/TDD_NUM); j++){
      for(k = 0; k < N_col; k++){
        if(((j*TDD_NUM+tid)-k)>=0){
          Vect_H[j*TDD_NUM+tid] += (r[(j*TDD_NUM+tid)-k]*H[k]);
        }
      }
    }
  }
  __syncthreads_block(barId, TDD_NUM);
  //Down Sampling
  if(tid < TDD_NUM)
    for (j=0; j < N_sim/N_samp/TDD_NUM; j++)
      Vect_Dn[(j*TDD_NUM+tid)]=Vect_H[(j*TDD_NUM+tid)*N_samp];

  //Up Sampling
  if(tid < TDD_NUM)
    for (j=0; j < N_sim/N_samp/TDD_NUM;j++)
      Vect_Up[(j*TDD_NUM+tid)*N_samp]=Vect_Dn[(j*TDD_NUM+tid)];
  __syncthreads_block(barId, TDD_NUM);

  //convolving F
  if(tid < TDD_NUM){
    for (j=0; j< (N_sim/TDD_NUM); j++){
      for(k = 0; k < N_col; k++){
        if(((j*TDD_NUM+tid)-k)>=0){
          Vect_F[j*TDD_NUM+tid]+=(F[k]*Vect_Up[(j*TDD_NUM+tid)-k]);
        }
      }
    }
  }
}

void h_FBCore(float *r, float *H, float *Vect_H, float *Vect_Dn, float *Vect_Up, float *Vect_F, float *F){
  int j, k, p;
  //convolving H
  for (j=0; j< N_sim; j++)
  {
      //for (k=0; ((k<N_col) & ((j-k)>=0)); k++)
      for(k = 0; k < N_col; k++){
        if((j-k)>=0){
        //Vect_H[j]+=H[k]*r[j-k];
          Vect_H[j] += (r[j-k]*H[k]);
        }
      }
  }

  //Down Sampling
  for (j=0; j < N_sim/N_samp; j++)
    Vect_Dn[j]=Vect_H[j*N_samp];

  //Up Sampling
  for (j=0; j < N_sim/N_samp;j++)
    Vect_Up[j*N_samp]=Vect_Dn[j];

  //convolving F
  for (j=0; j< N_sim; j++)
  {
      //for (k=0; ((k<N_col) & ((j-k)>=0)); k++)
      for(k = 0; k < N_col; k++){
        if((j-k)>=0){
        //Vect_H[j]+=H[k]*r[j-k];
          Vect_F[j]+=(F[k]*Vect_Up[j-k]);
        }
      }
  }

}

/* DES key schedule */

int des_main_ks( uint32 *SK, uint8 *key )
{
    int i;
    uint32 X, Y, T;

    GET_UINT32( X, key, 0 );
    GET_UINT32( Y, key, 4 );

    /* Permuted Choice 1 */

    T =  ((Y >>  4) ^ X) & 0x0F0F0F0F;  X ^= T; Y ^= (T <<  4);
    T =  ((Y      ) ^ X) & 0x10101010;  X ^= T; Y ^= (T      );

    X =   (LHs[ (X      ) & 0xF] << 3) | (LHs[ (X >>  8) & 0xF ] << 2)
        | (LHs[ (X >> 16) & 0xF] << 1) | (LHs[ (X >> 24) & 0xF ]     )
        | (LHs[ (X >>  5) & 0xF] << 7) | (LHs[ (X >> 13) & 0xF ] << 6)
        | (LHs[ (X >> 21) & 0xF] << 5) | (LHs[ (X >> 29) & 0xF ] << 4);

    Y =   (RHs[ (Y >>  1) & 0xF] << 3) | (RHs[ (Y >>  9) & 0xF ] << 2)
        | (RHs[ (Y >> 17) & 0xF] << 1) | (RHs[ (Y >> 25) & 0xF ]     )
        | (RHs[ (Y >>  4) & 0xF] << 7) | (RHs[ (Y >> 12) & 0xF ] << 6)
        | (RHs[ (Y >> 20) & 0xF] << 5) | (RHs[ (Y >> 28) & 0xF ] << 4);

    X &= 0x0FFFFFFF;
    Y &= 0x0FFFFFFF;

    /* calculate subkeys */

    for( i = 0; i < 16; i++ )
    {
        if( i < 2 || i == 8 || i == 15 )
        {
            X = ((X <<  1) | (X >> 27)) & 0x0FFFFFFF;
            Y = ((Y <<  1) | (Y >> 27)) & 0x0FFFFFFF;
        }
        else
        {
            X = ((X <<  2) | (X >> 26)) & 0x0FFFFFFF;
            Y = ((Y <<  2) | (Y >> 26)) & 0x0FFFFFFF;
        }
	*SK++ =   ((X <<  4) & 0x24000000) | ((X << 28) & 0x10000000)
                | ((X << 14) & 0x08000000) | ((X << 18) & 0x02080000)
                | ((X <<  6) & 0x01000000) | ((X <<  9) & 0x00200000)
                | ((X >>  1) & 0x00100000) | ((X << 10) & 0x00040000)
                | ((X <<  2) & 0x00020000) | ((X >> 10) & 0x00010000)
                | ((Y >> 13) & 0x00002000) | ((Y >>  4) & 0x00001000)
                | ((Y <<  6) & 0x00000800) | ((Y >>  1) & 0x00000400)
                | ((Y >> 14) & 0x00000200) | ((Y      ) & 0x00000100)
                | ((Y >>  5) & 0x00000020) | ((Y >> 10) & 0x00000010)
                | ((Y >>  3) & 0x00000008) | ((Y >> 18) & 0x00000004)
                | ((Y >> 26) & 0x00000002) | ((Y >> 24) & 0x00000001);

        *SK++ =   ((X << 15) & 0x20000000) | ((X << 17) & 0x10000000)
                | ((X << 10) & 0x08000000) | ((X << 22) & 0x04000000)
                | ((X >>  2) & 0x02000000) | ((X <<  1) & 0x01000000)
                | ((X << 16) & 0x00200000) | ((X << 11) & 0x00100000)
                | ((X <<  3) & 0x00080000) | ((X >>  6) & 0x00040000)
                | ((X << 15) & 0x00020000) | ((X >>  4) & 0x00010000)
                | ((Y >>  2) & 0x00002000) | ((Y <<  8) & 0x00001000)
                | ((Y >> 14) & 0x00000808) | ((Y >>  9) & 0x00000400)
                | ((Y      ) & 0x00000200) | ((Y <<  7) & 0x00000100)
                | ((Y >>  7) & 0x00000020) | ((Y >>  3) & 0x00000011)
                | ((Y <<  2) & 0x00000004) | ((Y >> 21) & 0x00000002);
    }

    return( 0 );
}

int des_set_key( uint32 *esk, uint32 *dsk, uint8 key1[8],
                                uint8 key2[8], uint8 key3[8])
{
    int i;

    /* setup encryption subkeys */

    des_main_ks( esk, key1 );
    des_main_ks( dsk + 32, key2 );
    des_main_ks( esk + 64, key3 );



    /* setup decryption subkeys */

    for( i = 0; i < 32; i += 2 )
    {
        dsk[i] = esk[94 - i];
        dsk[i + 1] = esk[95 - i];
        esk[i + 32] = dsk[62 - i];
        esk[i + 33] = dsk[63 - i];
        dsk[i + 64] = esk[30 - i];
        dsk[i + 65] = esk[31 - i];

    }

    return( 0 );
}

__device__ void DES_ROUND_dev(uint32 *SK, uint32 X, uint32 Y)
{
    uint32 T;

    T = *SK ^ X;
    Y ^= SB8[ (T      ) & 0x3F ] ^
         SB6[ (T >>  8) & 0x3F ] ^
         SB4[ (T >> 16) & 0x3F ] ^
         SB2[ (T >> 24) & 0x3F ];

    T = *SK++ ^ ((X << 28) | (X >> 4));
    Y ^= SB7[ (T      ) & 0x3F ] ^
         SB5[ (T >>  8) & 0x3F ] ^
         SB3[ (T >> 16) & 0x3F ] ^
         SB1[ (T >> 24) & 0x3F ];
}

__device__ void des_crypt_dev( uint32 *SK, uint8 *input, uint8 *output, int len, int baseTid)
{
    int i;
    uint32 X, Y, T;
    int tid = baseTid + (threadIdx.x & 0x1f);
    if(tid < TDD_NUM){
      for(i = 0; i < len/TDD_NUM; i++){

        X = ( (uint32) *(input + (i*TDD_NUM+tid)*8) << 24 )
        | ( (uint32) *(input + ((i*TDD_NUM+tid)*8) + 1) << 16 )
        | ( (uint32) *(input + ((i*TDD_NUM+tid)*8) + 2) <<  8 )
        | ( (uint32) *(input + ((i*TDD_NUM+tid)*8) + 3)       );

        Y = ( (uint32) *(input + ((i*TDD_NUM+tid)*8) + 4) << 24 )
        | ( (uint32) *(input + ((i*TDD_NUM+tid)*8) + 5) << 16 )
        | ( (uint32) *(input + ((i*TDD_NUM+tid)*8) + 6) <<  8 )
        | ( (uint32) *(input + ((i*TDD_NUM+tid)*8) + 7)       );


        DES_IP( X, Y );

        DES_ROUND_dev( SK, Y, X );  DES_ROUND_dev( (SK + 2), X, Y );
        DES_ROUND_dev( (SK + 4), Y, X );  DES_ROUND_dev( (SK + 6), X, Y );
        DES_ROUND_dev( (SK + 8), Y, X );  DES_ROUND_dev( (SK + 10), X, Y );
        DES_ROUND_dev( (SK + 12), Y, X );  DES_ROUND_dev( (SK + 14), X, Y );
        DES_ROUND_dev( (SK + 16), Y, X );  DES_ROUND_dev( (SK + 18), X, Y );
        DES_ROUND_dev( (SK + 20), Y, X );  DES_ROUND_dev( (SK + 22), X, Y );
        DES_ROUND_dev( (SK + 24), Y, X );  DES_ROUND_dev( (SK + 26), X, Y );
        DES_ROUND_dev( (SK + 28), Y, X );  DES_ROUND_dev( (SK + 30), X, Y );

        DES_ROUND_dev( (SK + 32), X, Y );  DES_ROUND_dev( (SK + 34), Y, X );
        DES_ROUND_dev( (SK + 36), X, Y );  DES_ROUND_dev( (SK + 38), Y, X );
        DES_ROUND_dev( (SK + 40), X, Y );  DES_ROUND_dev( (SK + 42), Y, X );
        DES_ROUND_dev( (SK + 44), X, Y );  DES_ROUND_dev( (SK + 46), Y, X );
        DES_ROUND_dev( (SK + 48), X, Y );  DES_ROUND_dev( (SK + 50), Y, X );
        DES_ROUND_dev( (SK + 52), X, Y );  DES_ROUND_dev( (SK + 54), Y, X );
        DES_ROUND_dev( (SK + 56), X, Y );  DES_ROUND_dev( (SK + 58), Y, X );
        DES_ROUND_dev( (SK + 60), X, Y );  DES_ROUND_dev( (SK + 62), Y, X );

        DES_ROUND_dev( (SK + 64), Y, X );  DES_ROUND_dev( (SK + 66), X, Y );
        DES_ROUND_dev( (SK + 68), Y, X );  DES_ROUND_dev( (SK + 70), X, Y );
        DES_ROUND_dev( (SK + 72), Y, X );  DES_ROUND_dev( (SK + 74), X, Y );
        DES_ROUND_dev( (SK + 76), Y, X );  DES_ROUND_dev( (SK + 78), X, Y );
        DES_ROUND_dev( (SK + 80), Y, X );  DES_ROUND_dev( (SK + 82), X, Y );
        DES_ROUND_dev( (SK + 84), Y, X );  DES_ROUND_dev( (SK + 86), X, Y );
        DES_ROUND_dev( (SK + 88), Y, X );  DES_ROUND_dev( (SK + 90), X, Y );
        DES_ROUND_dev( (SK + 92), Y, X );  DES_ROUND_dev( (SK + 94), X, Y );

        DES_FP( Y, X );

      *(output + (i*TDD_NUM+tid)*8) = (uint8) ( (Y) >> 24 );
      *(output + ((i*TDD_NUM+tid)*8) + 1) = (uint8) ( (Y) >> 16 );
      *(output + ((i*TDD_NUM+tid)*8) + 2) = (uint8) ( (Y) >>  8 );
      *(output + ((i*TDD_NUM+tid)*8) + 3) = (uint8) ( (Y)       );
      *(output + ((i*TDD_NUM+tid)*8) + 4) = (uint8) ( (X) >> 24 );
      *(output + ((i*TDD_NUM+tid)*8) + 5) = (uint8) ( (X) >> 16 );
      *(output + ((i*TDD_NUM+tid)*8) + 6) = (uint8) ( (X) >>  8 );
      *(output + ((i*TDD_NUM+tid)*8) + 7) = (uint8) ( (X)       );

      }
    }
}
__device__ void des_encrypt_dev( uint32 *esk, uint32 *dsk, uint8 *input, uint8 *output, int len, int baseTid)
{
    des_crypt_dev( esk, input, input, len, baseTid);
    des_crypt_dev( dsk, input, output, len, baseTid);
}

void DES_ROUND(uint32 *SK, uint32 X, uint32 Y)
{
    uint32 T;

    T = *SK ^ X;
    Y ^= SB88[ (T      ) & 0x3F ] ^
         SB66[ (T >>  8) & 0x3F ] ^
         SB44[ (T >> 16) & 0x3F ] ^
         SB22[ (T >> 24) & 0x3F ];

    T = *SK++ ^ ((X << 28) | (X >> 4));
    Y ^= SB77[ (T      ) & 0x3F ] ^
         SB55[ (T >>  8) & 0x3F ] ^
         SB33[ (T >> 16) & 0x3F ] ^
         SB11[ (T >> 24) & 0x3F ];
}

/* DES 64-bit block encryption/decryption */

void des_crypt( uint32 *SK, uint8 *input, uint8 *output, int len)
{
    int i;
    uint32 X, Y, T;

    for(i = 0; i < len; i++){
      X = ( (uint32) *(input + i*8) << 24 )
        | ( (uint32) *(input + (i*8) + 1) << 16 )
        | ( (uint32) *(input + (i*8) + 2) <<  8 )
        | ( (uint32) *(input + (i*8) + 3)       );

      Y = ( (uint32) *(input + (i*8) + 4) << 24 )
        | ( (uint32) *(input + (i*8) + 5) << 16 )
        | ( (uint32) *(input + (i*8) + 6) <<  8 )
        | ( (uint32) *(input + (i*8) + 7)       );

      DES_IP( X, Y );

      DES_ROUND( SK, Y, X );  DES_ROUND( (SK + 2), X, Y );
      DES_ROUND( (SK + 4), Y, X );  DES_ROUND( (SK + 6), X, Y );
      DES_ROUND( (SK + 8), Y, X );  DES_ROUND( (SK + 10), X, Y );
      DES_ROUND( (SK + 12), Y, X );  DES_ROUND( (SK + 14), X, Y );
      DES_ROUND( (SK + 16), Y, X );  DES_ROUND( (SK + 18), X, Y );
      DES_ROUND( (SK + 20), Y, X );  DES_ROUND( (SK + 22), X, Y );
      DES_ROUND( (SK + 24), Y, X );  DES_ROUND( (SK + 26), X, Y );
      DES_ROUND( (SK + 28), Y, X );  DES_ROUND( (SK + 30), X, Y );

      DES_ROUND( (SK + 32), X, Y );  DES_ROUND( (SK + 34), Y, X );
      DES_ROUND( (SK + 36), X, Y );  DES_ROUND( (SK + 38), Y, X );
      DES_ROUND( (SK + 40), X, Y );  DES_ROUND( (SK + 42), Y, X );
      DES_ROUND( (SK + 44), X, Y );  DES_ROUND( (SK + 46), Y, X );
      DES_ROUND( (SK + 48), X, Y );  DES_ROUND( (SK + 50), Y, X );
      DES_ROUND( (SK + 52), X, Y );  DES_ROUND( (SK + 54), Y, X );
      DES_ROUND( (SK + 56), X, Y );  DES_ROUND( (SK + 58), Y, X );
      DES_ROUND( (SK + 60), X, Y );  DES_ROUND( (SK + 62), Y, X );

      DES_ROUND( (SK + 64), Y, X );  DES_ROUND( (SK + 66), X, Y );
      DES_ROUND( (SK + 68), Y, X );  DES_ROUND( (SK + 70), X, Y );
      DES_ROUND( (SK + 72), Y, X );  DES_ROUND( (SK + 74), X, Y );
      DES_ROUND( (SK + 76), Y, X );  DES_ROUND( (SK + 78), X, Y );
      DES_ROUND( (SK + 80), Y, X );  DES_ROUND( (SK + 82), X, Y );
      DES_ROUND( (SK + 84), Y, X );  DES_ROUND( (SK + 86), X, Y );
      DES_ROUND( (SK + 88), Y, X );  DES_ROUND( (SK + 90), X, Y );
      DES_ROUND( (SK + 92), Y, X );  DES_ROUND( (SK + 94), X, Y );

      DES_FP( Y, X );

      *(output + i*8) = (uint8) ( (Y) >> 24 );
      *(output + (i*8) + 1) = (uint8) ( (Y) >> 16 );
      *(output + (i*8) + 2) = (uint8) ( (Y) >>  8 );
      *(output + (i*8) + 3) = (uint8) ( (Y)       );
      *(output + (i*8) + 4) = (uint8) ( (X) >> 24 );
      *(output + (i*8) + 5) = (uint8) ( (X) >> 16 );
      *(output + (i*8) + 6) = (uint8) ( (X) >>  8 );
      *(output + (i*8) + 7) = (uint8) ( (X)       );

    }
}

void des_encrypt( uint32 *esk, uint32 *dsk, uint8 *input, uint8 *output, int len)
{
    des_crypt( esk, input, input, len);
    des_crypt( dsk, input, output, len);
}

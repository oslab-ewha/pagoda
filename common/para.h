#define SM_NUM 		24  			// the number of SM
#define BK_NUM 		(SM_NUM*2)  		// the number of thread block
#define TD_NUM 		1024  			// the number of thread in one thread block
#define BP_NUM 		32 			// the number of task buffer per pool
#define WP_SIZE 	(BK_NUM*TD_NUM/32) 	// total number of warps in a GPU
#define SH_MEM_SIZE 	16384 			// the size of shared memory in one thread block
#define SH_TREE_SIZE 	64 			// the size of buddy system tree
#define MAX_BK 		16 			// the max number of block in one SM
#define warpSize 	32 			// the number of thread in a warp
#define paraNum 	16 			// the number of parameters
#define inParaNum 	5			// the num. of thread, block ... params
#define syncNum 	16 			// the number of sync Id
#define streamNum 	1024 			// the number of cuda stream
#define batchSize	384		

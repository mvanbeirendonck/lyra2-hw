#include <malloc.h>
#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "Lyra2RE.h"
#include "sph_blake.h"
#include "sph_groestl.h"
#include "sph_cubehash.h"
#include "sph_bmw.h"
#include "sph_keccak.h"
#include "sph_skein.h"
#include "Lyra2.h"


void print_hashline(FILE* file_in, uint8_t* data_in, int hash_size) {
	unsigned int j;
	uint8_t* ptr;

	ptr = data_in + hash_size - 1;

	for (j = 0; j < hash_size; j++) {
		fprintf(file_in, "%02x", *ptr);
		ptr -= 1;
	}

	fprintf(file_in, "\n");
}

void Vectors_VHDL() {

	const unsigned int hash_size = 32; //uint8_t
	const unsigned int in_size = 80; //uint8_t

	//FILE *f_in_blake, *f_out_blake;
	//FILE *f_in_keccak, *f_out_keccak;
	//FILE *f_in_cube1, *f_out_cube1;
	FILE *f_in_lyra, *f_out_lyra;
	//FILE *f_in_skein, *f_out_skein;
	//FILE *f_in_cube2, *f_out_cube2;
	//FILE *f_in_bmw, *f_out_bmw;

	unsigned int count_test;
	unsigned int num_test = 1000;
	uint8_t block_input[in_size];

	uint8_t blake_out[hash_size];
	uint8_t keccak_out[hash_size];
	uint8_t cube1_out[hash_size];
	uint8_t lyra2_out[hash_size];
	uint8_t skein_out[hash_size];
	uint8_t cube2_out[hash_size];
	uint8_t bmw_out[hash_size];

    	//f_in_blake = fopen(PROJECT_PATH "/hdl/blake/sim/vectors/blake_in.txt","w");
	//f_out_blake = fopen(PROJECT_PATH "/hdl/blake/sim/vectors/blake_ref_out.txt","w");

	//f_in_keccak =fopen(PROJECT_PATH "/hdl/keccak/sim/vectors/keccak_in.txt","w");
	//f_out_keccak =fopen(PROJECT_PATH "/hdl/keccak/sim/vectors/keccak_ref_out.txt","w");

	//f_in_cube1 =fopen(PROJECT_PATH "/hdl/cubehash/sim/vectors/cube1_in.txt","w");
	//f_out_cube1 =fopen(PROJECT_PATH "/hdl/cubehash/sim/vectors/cube1_ref_out.txt","w");

	f_in_lyra =fopen(PROJECT_PATH "/hdl/lyra2/sim/vectors/lyra2_in.txt","w");
	f_out_lyra =fopen(PROJECT_PATH "/hdl/lyra2/sim/vectors/lyra2_ref_out.txt","w");

	//f_in_skein =fopen(PROJECT_PATH "/hdl/skein/sim/vectors/skein_in.txt","w");
	//f_out_skein =fopen(PROJECT_PATH "/hdl/skein/sim/vectors/skein_ref_out.txt","w");

	//f_in_cube2 =fopen(PROJECT_PATH "/hdl/cubehash/sim/vectors/cube2_in.txt","w");
	//f_out_cube2 =fopen(PROJECT_PATH "/hdl/cubehash/sim/vectors/cube2_ref_out.txt","w");

	//f_in_bmw =fopen(PROJECT_PATH "/hdl/bmw/sim/vectors/bmw_in.txt","w");
	//f_out_bmw =fopen(PROJECT_PATH "/hdl/bmw/sim/vectors/bmw_ref_out.txt","w");

	srand(0);

	for (count_test = 0; count_test < num_test; count_test++) {

		//gen random block_input
		unsigned int j;
		for (j = 0; j < in_size; j++)
			block_input[j] = (uint8_t) rand();

		sph_blake256_context ctx_blake;
		sph_cubehash256_context ctx_cubehash;
		sph_keccak256_context ctx_keccak;
		sph_skein256_context ctx_skein;
		sph_bmw256_context ctx_bmw;

		//print_hashline(f_in_blake, block_input, in_size);
		sph_blake256_init(&ctx_blake);
		sph_blake256(&ctx_blake, block_input, 80);
		sph_blake256_close(&ctx_blake, blake_out);
		//print_hashline(f_out_blake, blake_out, hash_size);

		//print_hashline(f_in_keccak, blake_out, hash_size);
		sph_keccak256_init(&ctx_keccak);
		sph_keccak256(&ctx_keccak, blake_out, 32);
		sph_keccak256_close(&ctx_keccak, keccak_out);
		//print_hashline(f_out_keccak, keccak_out, hash_size);

		//print_hashline(f_in_cube1, keccak_out, hash_size);
		sph_cubehash256_init(&ctx_cubehash);
		sph_cubehash256(&ctx_cubehash, keccak_out, 32);
		sph_cubehash256_close(&ctx_cubehash, cube1_out);
		//print_hashline(f_out_cube1, cube1_out, hash_size);

		print_hashline(f_in_lyra, cube1_out, hash_size);
		LYRA2(lyra2_out, 32, cube1_out, 32, cube1_out, 32, 1, 4, 4);
		print_hashline(f_out_lyra, lyra2_out, hash_size);

		//print_hashline(f_in_skein, lyra2_out, hash_size);
		sph_skein256_init(&ctx_skein);
		sph_skein256(&ctx_skein, lyra2_out, 32);
		sph_skein256_close(&ctx_skein, skein_out);
		//print_hashline(f_out_skein, skein_out, hash_size);

		//print_hashline(f_in_cube2, skein_out, hash_size);
		sph_cubehash256_init(&ctx_cubehash);
		sph_cubehash256(&ctx_cubehash, skein_out, 32);
		sph_cubehash256_close(&ctx_cubehash, cube2_out);
		//print_hashline(f_out_cube2, cube2_out, hash_size);

		//print_hashline(f_in_bmw, cube2_out, hash_size);
		sph_bmw256_init(&ctx_bmw);
		sph_bmw256(&ctx_bmw, cube2_out, 32);
		sph_bmw256_close(&ctx_bmw, bmw_out);
		//print_hashline(f_out_bmw, bmw_out, hash_size);

	}
}

int main() {
	Vectors_VHDL();
    	printf("INFO :: Generated all testbench vectors.\n"); 
    	return 0; 
}

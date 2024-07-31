#!/bin/bash  

echo "Creating snarkjs proof and verifier and verifier.sol"

npm install -g snarkjs@latest

#  Create and move into a new directory
mkdir snarkjs_demo
cd snarkjs_demo

# Start a new powers of tau ceremony. we support both bn128 and bls12-381
# Usage:  snarkjs ptn <curve> <power> [powersoftau_0000.ptau]
snarkjs ptn bn128 14 pot14_0000.ptau --verbose

# 2. Contribute to the ceremony
# Usage:  snarkjs ptc <powersoftau.ptau> <new_powersoftau.ptau>
snarkjs ptc pot14_0000.ptau pot14_0001.ptau --name="First contribution" -v

# 3. Provide a second contribution
snarkjs ptc pot14_0001.ptau pot14_0002.ptau --name="Second contribution" -v -e="Love the way you lie."

# 4. Provide a third contribution using third party software

# Usage:  snarkjs ptec <powersoftau_0000.ptau> [challenge]
snarkjs ptec pot14_0002.ptau challenge_0003

# Usage:  snarkjs ptcc <curve> <challenge> [response]
snarkjs ptcc bn128 challenge_0003 response_0003 -e="Good man the lantern"

# Usage:  snarkjs ptir <powersoftau_old.ptau> <response> <<powersoftau_new.ptau>  : import a response to a ptau file
snarkjs ptir pot14_0002.ptau response_0003 pot14_0003.ptau -n="Third contribution name"

# 5. Verify the protocol so far

# Usage:  snarkjs ptv <powersoftau.ptau>
echo "verifying the protocol so far..."
snarkjs ptv pot14_0003.ptau
echo "================ thanks for your patience =========="

# 6. Apply a random beacon
# Usage:  snarkjs ptb <old_powersoftau.ptau> <new_powersoftau.ptau> <beaconHash(Hex)> <numIterationsExp>
snarkjs ptb pot14_0003.ptau pot14_beacon.ptau 0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f 10 -n="Final Beacon"

# 7. Prepare phase 2
# Usage:  snarkjs pt2 <powersoftau.ptau> <new_powersoftau.ptau>
snarkjs pt2 pot14_beacon.ptau pot14_final.ptau --verbose

# 8. Verify the final ptau
# Usage:  snarkjs ptv <powersoftau.ptau>
snarkjs ptv pot14_final.ptau

# 9. Create the circuit
echo "Creating circuit code in circuit.circom..."

cat <<EOT > circuit.circom

pragma circom 2.1.9;

template Multiplier(n) {
   signal input a;
   signal input b;

   signal output r;

   signal s[n];

   s[0] <== a * a + b;
   for(var i = 1; i < n; i++)  {
      s[i] <== s[i-1] * s[i-1] + b;
   }

   r <== s[n-1];

}

component main = Multiplier(1000);
EOT

echo "circuit.circom is created successfully!"


# 10. Compile the circuit

circom circuit.circom --r1cs --wasm --sym

# 11. View information about the circuit & Print the constraints
echo "View information about the circuit"
snarkjs r1cs info circuit.r1cs

echo "Printing the constraints......"
snarkjs r1cs print circuit.r1cs circuit.sym

# 13. Export r1cs to json
snarkjs r1cs export json circuit.r1cs circuit.r1cs.json
cat circuit.r1cs.json

# 14. Calculate the witness

cat <<EOT > input.json
{"a": 3, "b": 11}
EOT

cd circuit_js
node generate_witness.js circuit.wasm ../input.json ../witness.wtns
cd ..
snarkjs wtns check circuit.r1cs witness.wtns

# 15. Setup

# Usage:  snarkjs g16s [circuit.r1cs] [powersoftau.ptau] [circuit_0000.zkey]
 snarkjs g16s circuit.r1cs pot14_final.ptau circuit_0000.zkey

# 16. Contribute to the phase 2 ceremony

# Usage:  snarkjs zkc <circuit_old.zkey> <circuit_new.zkey>
snarkjs zkc circuit_0000.zkey circuit_0001.zkey --name="Goldy" -v

# 17. Provide a second contribution
snarkjs zkc circuit_0001.zkey circuit_0002.zkey --name="Goldy Masala" -v -e="have a nice day"

# 18. Provide a third contribution using third party software

echo "Export a zKey to a MPCParameters file compatible with kobi/phase2 (Bellman)"
# Usage:  snarkjs zkeb <circuit_xxxx.zkey> [circuit.mpcparams]
snarkjs zkeb circuit_0002.zkey  challenge_phase2_0003

# contributes to a challenge file in bellman format
# Usage:  snarkjs zkbc <curve> <circuit.mpcparams> <circuit_response.mpcparams>
snarkjs zkbc bn128 challenge_phase2_0003 response_phase2_0003 -e="Balle balle"

# Export a zKey to a MPCParameters file compatible with kobi/phase2 (Bellman) 
# Usage:  snarkjs zkib <circuit_old.zkey> <circuit.mpcparams> <circuit_new.zkey>
snarkjs zkib circuit_0002.zkey response_phase2_0003 circuit_0003.zkey -n="Proud to be goldy bhai"

# 19. Verify the latest zkey

# Usage:  snarkjs zkv [circuit.r1cs] [powersoftau.ptau] [circuit_final.zkey]
echo "verifying latest zkey ..."
snarkjs zkv circuit.r1cs pot14_final.ptau circuit_0003.zkey

# 20. Apply a random beacon

#Usage:  snarkjs zkb <circuit_old.zkey> <circuit_new.zkey> <beaconHash(Hex)> <numIterationsExp>
snarkjs zkb circuit_0003.zkey circuit_final.zkey 0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f 10 -n="Final Beacon phase2"

# 21. Verify the final zkey
#Usage:  snarkjs zkv [circuit.r1cs] [powersoftau.ptau] [circuit_final.zkey]
echo "verifying final zkey..."
snarkjs zkv circuit.r1cs pot14_final.ptau circuit_final.zkey

# 22. Export the verification key
# Usage:  snarkjs zkev [circuit_final.zkey] [verification_key.json]
snarkjs zkev circuit_final.zkey verification_key.json

# 23. Create the proof

echo "Creating proof (proof.json & public.json)..."
# Usage:  snarkjs g16p [circuit_final.zkey] [witness.wtns] [proof.json] [public.json]
snarkjs g16p circuit_final.zkey witness.wtns proof.json public.json

# 24. Verify the proof
echo "verifying proof ..."
# Usage:  snarkjs g16v [verification_key.json] [public.json] [proof.json]
snarkjs g16v verification_key.json public.json proof.json

# 25. Turn the verifier into a smart contract
echo "Turning the verifier into a smart contract (verifier.sol)"
# Usage:  snarkjs zkesv [circuit_final.zkey] [verifier.sol]

snarkjs zkesv circuit_final.zkey verifier.sol
echo "verifier.sol SmartContract is generated successfully!"

# 26. Simulate a verification call
echo "verifier.sol - publish it on-chain -- using remix and test with following soliditycalldata"
echo "Generating soliditycalldata..."
# Usage:  snarkjs zkesc [public.json] [proof.json]
snarkjs zkesc public.json proof.json



echo "========== Happy ending! ======"
/* MIT License

Copyright (c) 2021 Maarten Zuidhoorn

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

import assert from "assert";
import { SigningKey } from "@ethersproject/signing-key";
import { getMessage, keccak256 } from "eip-712";

export default function sign(typedData: any, privateKey: string) {
  const EIP_3074_MAGIC = Buffer.from([0x03]);

  assert(privateKey, "No private key provided");

  const signingKey = new SigningKey(privateKey);

  const commit = getMessage(typedData, true);

  const buffer = keccak256(
    Buffer.concat([
      EIP_3074_MAGIC,
      Buffer.from(
        typedData.domain.verifyingContract.slice(2).padStart(64, "0"),
        "hex"
      ),
      commit,
    ]).toString("hex"),
    "hex"
  );

  const { r, s, v: recovery } = signingKey.signDigest(buffer);
  const v = Boolean(recovery - 27);

  return { r, s, v };
}

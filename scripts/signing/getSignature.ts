import payload from "./payload.json";
import sign from "./sign";
import * as tracking from "../tracking/record";

export default function getSignature(message: any, privateKey: string) {
  const records = tracking.read();

  const typedData = {
    ...payload,
    domain: {
      ...payload.domain,
      chainId: records.chainId,
      verifyingContract: records.invoker,
    },
    message,
  };

  return sign(typedData, privateKey);
}

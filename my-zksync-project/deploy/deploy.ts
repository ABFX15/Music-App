import { deployContract } from "./utils";

export default async function () {
  const Paymaster = "GeneralPaymaster";
  const PaymasterArguments: string[] = [];
  await deployContract(Paymaster, PaymasterArguments);

  const contractArtifactName = "zkTune";
  const dAppArguments: string[] = [];
  await deployContract(contractArtifactName, dAppArguments);
}

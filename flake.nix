{
  description = "OpenShift UPI Lab on GCP";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          # GCP CLI with components for Nested Virt management
          (google-cloud-sdk.withExtraComponents [
            google-cloud-sdk.components.alpha
            google-cloud-sdk.components.beta
            google-cloud-sdk.components.gke-gcloud-auth-plugin
          ])
          terraform
          openshift
          jq
          yq-go
        ];

        shellHook = ''
          echo "☁️ GCP OpenShift Lab Environment Loaded"
          # Ensure gcloud uses your local project config
          export CLOUDSDK_CONFIG=$PWD/.gcloud
          # Useful alias for the installer you'll download manually
          alias os-install="./openshift-install"
        '';
      };
    };
}

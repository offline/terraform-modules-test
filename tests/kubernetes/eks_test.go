package test

import (
	"crypto/tls"
	"fmt"
	"testing"
	"encoding/pem"
	"crypto/x509"
	"log"

	// "github.com/aws/aws-sdk-go/service/ec2"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/terraform"
	stage "github.com/gruntwork-io/terratest/modules/test-structure"
	// "github.com/stretchr/testify/assert"
)


func TestEksModule(t *testing.T) {
	// t.Parallel()

	testDataFolder := "../"

	// Make a copy of the terraform module to a temporary directory.
	// This allows running multiple tests in parallel
	// against the same terraform module.
	rootFolder := stage.CopyTerraformFolderToTemp(t, "../..", "examples/eks-cluster")

	stage.RunTestStage(t, "setup", func() {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			// The path to where our Terraform code is located
			TerraformDir: rootFolder,

			// Variables to pass to our Terraform code using -var options
			// Vars: map[string]interface{}{
			// 	"instance_name": expectedName,
			// 	"instance_type": instanceType,
			// },

			// Environment variables to set when running Terraform
			// EnvVars: map[string]string{
			// 	"AWS_DEFAULT_REGION": awsRegion,
			// },
		})

		stage.SaveTerraformOptions(t, testDataFolder, terraformOptions)

		terraform.InitAndApply(t, terraformOptions)
	})

	stage.RunTestStage(t, "validate", func() {
		terraformOptions := stage.LoadTerraformOptions(t, testDataFolder)
		fmt.Println(terraform.Output(t, terraformOptions, "eks_endpoint"))
		certBlock, _ := pem.Decode([]byte(terraform.Output(t, terraformOptions, "eks_certificate")))
	if certBlock == nil {
		log.Fatalf("failed to parse certificate PEM")
	}

	// Create a certificate object from the PEM data
	cert, err := x509.ParseCertificate(certBlock.Bytes)
	if err != nil {
		log.Fatalf("failed to parse certificate: %v", err)
	}

	// Create a certificate pool and add the certificate to it
	certPool := x509.NewCertPool()
	certPool.AddCert(cert)

	// Create a TLS configuration using the certificate pool
	tlsConfig := &tls.Config{
		RootCAs: certPool,
	}
		status_code, _ := http_helper.HttpGet(t, fmt.Sprintf("%s/healthz", terraform.Output(t, terraformOptions, "eks_endpoint")), tlsConfig)
		fmt.Println("Status code is:", status_code)
	})

	stage.RunTestStage(t, "teardown", func() {
		terraformOptions := stage.LoadTerraformOptions(t, testDataFolder)
		terraform.Destroy(t, terraformOptions)
	})
}

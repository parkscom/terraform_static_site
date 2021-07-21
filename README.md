AWS Terraform을 이용한 Static website 구축 템플릿
==============
[![MIT Licensed](https://img.shields.io/badge/license-MIT-green.svg)](https://tldrlegal.com/license/mit-license)
간단한 웹사이트 호스팅을 [Amazon AWS](https://aws.amazon.com/)을 이용하여 구축하거나, 특정 도메인에 접속한 사용자를 다른 사이트로 리다렉트(redirect) 시키는데 유용한 [Terraform](https://www.terraform.io/) 설정 파일입니다. AWS 콘솔에서 이런 종류의 작업이 가능하지만, Terraform을 이용할 경우 매우 빠르고 간편하게 사이트를 구축할 수 있습니다.

주요 특징
------------
- https를 지원합니다. https(TLS/SSL) 서비스를 구축하기 위한 별도의 인증서(Certfication)이 불필요합니다. 인증서는 AWS ACM(AWS Certificate Manager)을 통해서 발급 받아 사용합니다. 추가 비용이 들지 않고(free), 인증서 갱신이 AWS ACM 서비스를 통해서 자동으로 이루어집니다.
- 소규모의 순수 HTML 사이트를 구축하기 위해서 알맞습니다.
- 도메인 Redirect 기능은 보통 https://www.example.com 사이트를 구축해둔 상태에서, 보조 도메인인 https://www.example.co.kr을 접속한 사용자를 자동으로 redirect 시키는 기능으로 사용합니다. 물론, 2개의 도메인을 1개의 IP를 바라보도록 구축할 수도 있지만, https를 사용할 경우 인증서 충돌이 나서 정상적으로 동작하지 않습니다. (`https://www.example.com`에서 발급 받은 SSL 인증서는 example.co.kr 도메인에서 사용할 수 없습니다.) 또한 `https://www.example.com` 도메인을 구축하였지만, `https://example.com`으로 접속한 사용자를 `https://www.example.com` 도메인으로 유도하는 경우도 사용 가능합니다.
- AWS S3는 이미지와 같은 static content를 저장하고, Public으로 access할 수는 있지만, 사용자 도메인 설정과 https 설정이 불가능합니다. 이 부분을 해결하기 위해서 CloudFront를 사용합니다. CloudFront는 네트워크 종량제 서비스이므로 네트워크 사용량만큼 비용이 지불됩니다. 네트워크 사용에 따른 비용은 일반적으로 S3에 비해서 같거나 작습니다.

사용되는 AWS 구성 요소
------------
- S3 - static content 저장용
- ACM - TLS Certification 발급
- CloudFront - CDN, 도메인에 https 설정 지원

사전 필요 사항
------------
- AWS Account
- Terraform
- 사용할 도메인의 관리자 권한 (ACM 인증서 발급을 위해 DNS Record 변경 필요, 또는 [AWS Route53](https://aws.amazon.com/route53/) 사용)

간단한 웹사이트(static website) 구축
=============

Terraform을 사용하지 않고 수동으로 구축
-------------
- Amazon S3 버킷에 정적 웹사이트 호스팅하는 방법 <https://webruden.tistory.com/432>
- AWS 공식 가이드
  * <https://aws.amazon.com/premiumsupport/knowledge-center/cloudfront-serve-static-website/>
  * <https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html>
  * <https://docs.aws.amazon.com/AmazonS3/latest/userguide/how-to-page-redirect.html>


Terraform을 이용한 간단한 Static Site 구축
-------------
이 예제에서는 `https://www.example.com`을 구축하는 것을 가정합니다.
1. Terraform을 다운로드 및 설치 <https://learn.hashicorp.com/tutorials/terraform/install-cli>
2. (여러개의 사이트의 구축이 필요할 경우) static_site 디렉토리를 domain_static_site 디렉토리로 복사 (Terraform에서는 .terraform 디렉토리에 생성된 인스턴스에 대한 상태(state)가 관리되므로, 만일 동일 디렉토리에서 여러번 실행을 하게되면, 기존의 사이트가 종료되는 문제가 발생하게 됩니다.)
```bash
$ cp -r static_site example_static_site
```
3. AWS 연결을 위한 환경 변수를 설정
```bash
$ export AWS_ACCESS_KEY_ID="anaccesskey"
$ export AWS_SECRET_ACCESS_KEY="asecretkey"
```
4. Terraform 초기화
```bash
$ teraform init

Initializing the backend...

Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 3.27"...
... ...  ...
```

5. 사이트 구성을 위한 환경 변수 파일 설정을 수정합니다.
```bash
# Terraform으로 사이트를 구성하기 위해서는 3개의 환경 변수를 입력합니다.
# region - AWS 구성을 위한 Region
# site_domain - 구성될 사이트의 최종 도메인 이름
# site_name - 구성될 사이트의 서비스 이름 (S3의 Bucket의 이름으로 구성 사용되므로 전체 S3 사이트에서 유일한 값을 지정합니다.)


$cat terraform.tfvars
region      = "ap-northeast-2"
site_name   = "example-com"
site_domain = "www.example.com"
```

6. Terraform을 이용하여 구성될 인스턴스 계획(plan)을 확인하고, CloudFront, S3 등의 인스턴스를 생성 (apply)
```
$ terraform plan

$ terraform apply
```

7. 첫번째 `terraform apply`에서는 아래와 같은 오류가 발생하게 됩니다. 이 오류는 ACM에서 certification이 아직 정상적으로 생성되지 않았기 때문입니다. 
아래의 내용을 만나면 [ACM 관리자](https://console.aws.amazon.com/acm/)에 접속하여 [DNS 검증](https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html)을 정상적으로 구성합니다. 이 과정에서 DNS의 변경을 통해 도메인 소유자 인증이 이루어집니다.
```
Error: error creating CloudFront Distribution: InvalidViewerCertificate: The specified SSL certificate doesn't exist, isn't in us-east-1 region, isn't valid, or doesn't include a valid certificate chain.
	status code: 400, request id: 29ceeee0-82ee-46
```

8. ACM 관리자에서 정상적으로 도메인이 발급되었다면, 다시 한번 `terraform apply` 명령을 실행하여 구성을 마무리합니다.
```
$ terraform apply
...
site_cdn_domain_name = "drkk0f89lqe9n.cloudfront.net"
site_cdn_root_id = "E2AAO0OYTP2AG2"
site_s3_bucket = "example-com-tf-site-tf"
```

9. `terraform appy` 실행 결과로 나온 `site_cdn_domain_name` 값을 이용하여 DNS에 해당 도메인을 CNAME으로 설정합니다. Route53을 이용할 경우 [Route53 가이드](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-to-cloudfront-distribution.html)를 참고합니다.
```
# DNS Record
www.example.com IN CNAME drkk0f89lqe9n.cloudfront.net
```

10. 이제 [AWS S3 콘솔](https://console.aws.amazon.com/acm/) 또는 AWS CLI를 이용하여 HTML과 이미지 파일 등의 컨텐츠를 업로드합니다. 사이트의 시작 페이지는 index.html로 지정합니다. 컨텐츠 업로드가 완료되면, https://www.example.com/로 접속하여 사이트가 정상적으로 동작하는지 확인합니다.


Terraform을 이용한 도메인의 Redirect 설정
-------------
전체적인 과정은 static site 구축과 큰 차이가 없습니다. (이 예제에서는 https://example.com을 접속하면 https://www.example.com으로 redirect가 이루어지는 것을 가정합니다.)
1. Terraform 설치
2. (여러 사이트/도메인 관리가 필요할 경우) redirect_site 디렉토리를 domain_static_site 디렉토리로 복사
```bash
$ cp -r redirect_site example_redirect_site
```
3. AWS 연결을 위한 환경 변수를 설정
4. Terraform 초기화
5. 사이트 구성을 위한 환경 변수 파일 설정
```bash
# Redirect 사이트 구축을 위해서는 4개의 환경 변수를 입력합니다.
# region - AWS 구성을 위한 Region
# site_domain - 구성될 사이트의 최종 도메인 이름
# site_name - 구성될 사이트의 서비스 이름 (S3의 Bucket의 이름으로 구성 사용되므로 전체 S3 사이트에서 유일한 값을 지정합니다.)
# redirect_domain - 구성될 사이트의 최종 도메인 이름

$ cat terraform.tfvars
region          = "ap-northeast-2"
site_name       = "example-redirect"
site_domain     = "example.com"
redirect_domain = "www.example.com"
```
6. Terraform을 이용하여 구성될 인스턴스 계획(plan)을 확인하고, CloudFront, S3 등의 인스턴스를 생성 (apply)
```bash
$ terraform plan
$ terraform apply
```
7. ```terraform apply``` 수행 결과 발생한 오류를 해결하기 위해 ACM 콘솔에서 DNS 인증 작업 수행
8. ACM 관리자에서 정상적으로 도메인이 발급되었다면, 다시 한번 `terraform apply` 명령을 실행하여 구성을 마무리
```bash
$ terraform apply
...
site_cdn_domain_name = "drkk0f89lqe9n.cloudfront.net"
site_cdn_root_id = "E2AAO0OYTP2AG2"
site_s3_bucket = "example-com-tf-site-tf"
```
9. DNS 레코드를 CloudFront 도메인으로 연결합니다.
10. 사이트 정상 접속 확인
```bash
$ curl -v "https://example.com/"
...
< HTTP/1.1 301 Moved Permanently
< Location: https://www.example.com/
```


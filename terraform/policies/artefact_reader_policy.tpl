{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": ["s3:ListBucket"],
            "Resource": [
                "arn:aws:s3:::${artefact_bucket}"
            ]
        },
        {
            "Effect": "Allow",
            "Action": ["s3:GetObject"],
            "Resource": [
                "arn:aws:s3:::${artefact_bucket}",
                "arn:aws:s3:::${artefact_bucket}/*"
            ]
        }
    ]
}

"""
Signal handlers for program enrollments
"""
import logging
from django.db.models.signals import post_save
from django.dispatch import receiver
from social_django.models import UserSocialAuth
from student.models import CourseEnrollmentException
from third_party_auth.models import SAMLProviderConfig

from lms.djangoapps.program_enrollments.models import ProgramEnrollment

logger = logging.getLogger(__name__)


@receiver(post_save, sender=UserSocialAuth)
def populate_waiting_enrollments(sender, instance, **kwargs):  # pylint: disable=unused-argument
    """
    Post-save signal to update any waiting program enrollments with a user,
    and enroll the user in any waiting course enrollments.

    In most cases this will just short-circuit. Enrollments will only be updated
    for a SAML provider with a linked organization.
    """
    user = instance.user

    try:
        provider_slug, external_user_key = instance.uid.split(':')
        if not SAMLProviderConfig.objects.get(slug=provider_slug).organization:
            return
    except (SAMLProviderConfig.DoesNotExist, ValueError):
        return

    incomplete_enrollments = ProgramEnrollment.objects.filter(
        external_user_key=external_user_key
    ).prefetch_related('program_course_enrollments')

    incomplete_enrollments.update(user=user)

    for enrollment in incomplete_enrollments:
        for program_course_enrollment in enrollment.program_course_enrollments.all():
            try:
                program_course_enrollment.enroll(user)
            except CourseEnrollmentException as e:
                # TODO: eat exception w/ crit error vs. potentially block social_auth creation?
                logger.critical(
                    u'Failed to enroll waiting program_course_enrollment={}: {}'.format(program_course_enrollment.id, e)
                )

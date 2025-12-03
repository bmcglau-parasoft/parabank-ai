package com.parasoft.parabank.dao.jdbc;

import java.lang.reflect.Field;

import org.junit.Test;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.support.JdbcDaoSupport;
import org.springframework.test.util.ReflectionTestUtils;

import com.parasoft.parabank.test.util.AbstractParaBankDataSourceTest;

import jakarta.annotation.Resource;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.fail;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.nullable;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
/**
 * @req PAR-19
 *
 */
public class JdbcSequenceDaoTest extends AbstractParaBankDataSourceTest
{
    @Resource(name = "sequenceDao")
    private JdbcSequenceDao sequenceDao;

    public void setSequenceDao(final JdbcSequenceDao sequenceDao)
    {
        this.sequenceDao = sequenceDao;
    }

    @Test
    public void testGetNextId()
    {
        for (int i = 0; i < 10; i++) {
            assertEquals(12434 + i * JdbcSequenceDao.OFFSET, sequenceDao.getNextId("Customer"));
            assertEquals(13566 + i * JdbcSequenceDao.OFFSET, sequenceDao.getNextId("Account"));
            assertEquals(14476 + i * JdbcSequenceDao.OFFSET, sequenceDao.getNextId("Transaction"));
        }

        try {
            sequenceDao.getNextId(null);
            fail("did not throw expected DataAccessException");
        } catch (final DataAccessException e) {
        }

        try {
            sequenceDao.getNextId("");
            fail("did not throw expected DataAccessException");
        } catch (final DataAccessException e) {
        }
    }

    /**
     * Parasoft Jtest UTA: Test for getCurrentId(String)
     *
     * @see com.parasoft.parabank.dao.jdbc.JdbcSequenceDao#getCurrentId(String)
     * @author sv-jenkins
     */
    @Test(timeout = 5000)
    public void testGetCurrentId_ValidSequenceName() throws Throwable
    {
        // Given
        JdbcSequenceDao underTest = new JdbcSequenceDao();
        JdbcTemplate jdbcTemplateValue = mockJdbcTemplate();
        ReflectionTestUtils.setField(underTest, "jdbcTemplate", jdbcTemplateValue);

        // When
        String name = "sequenceName"; // UTA: LLM default value
        int result = underTest.getCurrentId(name);

        // Then - assertions for result of method getCurrentId(String)
        assertEquals(0, result);

    }

    /**
     * Parasoft Jtest UTA: Helper method to generate and configure mock of JdbcTemplate
     */
    private static JdbcTemplate mockJdbcTemplate() throws Throwable
    {
        JdbcTemplate jdbcTemplateValue = mock(JdbcTemplate.class);
        Object queryForObjectResult = null; // UTA: configured value
        when(jdbcTemplateValue.queryForObject(nullable(String.class), nullable(Object[].class), (Class) any())).thenReturn(queryForObjectResult);
        return jdbcTemplateValue;
    }

    /**
     * Parasoft Jtest UTA: Test for setNextId(String, int)
     *
     * @see com.parasoft.parabank.dao.jdbc.JdbcSequenceDao#setNextId(String, int)
     * @author sv-jenkins
     */
    @Test(timeout = 5000)
    public void testSetNextId_ValidSequenceNameAndId() throws Throwable
    {
        // Given
        JdbcSequenceDao underTest = new JdbcSequenceDao();
        JdbcTemplate jdbcTemplateValue = mockJdbcTemplate2();
        ReflectionTestUtils.setField(underTest, "jdbcTemplate", jdbcTemplateValue);

        // When
        String name = "sequenceName"; // UTA: LLM default value
        int nextId = 1024; // UTA: LLM default value
        int result = underTest.setNextId(name, nextId);

        // Then - assertions for result of method setNextId(String, int)
        assertEquals(0, result);

    }

    /**
     * Parasoft Jtest UTA: Helper method to generate and configure mock of JdbcTemplate
     */
    private static JdbcTemplate mockJdbcTemplate2() throws Throwable
    {
        JdbcTemplate jdbcTemplateValue = mock(JdbcTemplate.class);
        Object queryForObjectResult = null; // UTA: configured value
        when(jdbcTemplateValue.queryForObject(nullable(String.class), nullable(Object[].class), (Class) any())).thenReturn(queryForObjectResult);
        return jdbcTemplateValue;
    }
}
